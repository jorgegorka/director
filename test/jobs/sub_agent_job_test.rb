require "test_helper"

class SubAgentJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @role = roles(:cto)
    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id, status: RoleRun.statuses[:running])

    @project = @role.project
    Current.project = @project
  end

  # Stub Runner#run so no subprocess is spawned. Marks the invocation running
  # then completed (or failed, depending on the result kwarg) so terminal
  # transitions match production.
  def stub_runner(result:)
    SubAgents::Runner.define_singleton_method(:new) do
      fake = Object.new
      fake.define_singleton_method(:run) do |_sub_agent, invocation: nil|
        invocation&.mark_running!
        if result[:status] == "ok"
          invocation&.finish!(result_summary: result[:summary] || "done", cost_cents: 0, duration_ms: 10, iterations: 1)
        else
          invocation&.fail!(error_message: result[:error] || "failed", cost_cents: 0, duration_ms: 10, iterations: 1)
        end
        result
      end
      fake
    end
  end

  def unstub_runner
    SubAgents::Runner.singleton_class.remove_method(:new) rescue nil
  end

  test "job is enqueued to execution queue" do
    assert_equal "execution", SubAgentJob.new.queue_name
  end

  test "early-returns when invocation is missing" do
    assert_nothing_raised do
      SubAgentJob.perform_now(99_999, SubAgents::CreateTask.name, @role.id, {}, @role_run.id)
    end
  end

  test "early-returns when invocation is already terminal" do
    invocation = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "create_task")
    invocation.finish!(result_summary: "prior", cost_cents: 0, duration_ms: 1, iterations: 0)

    stub_runner(result: { status: "ok" })
    begin
      SubAgentJob.perform_now(invocation.id, SubAgents::CreateTask.name, @role.id, {}, @role_run.id)
    ensure
      unstub_runner
    end

    assert_equal "prior", invocation.reload.result_summary
  end

  test "happy path flips queued invocation through running to completed" do
    invocation = SubAgentInvocation.enqueue!(
      role_run: @role_run,
      sub_agent_name: "create_task",
      input_summary: "delegate"
    )
    assert invocation.queued?

    stub_runner(result: { status: "ok", summary: "created task" })
    begin
      SubAgentJob.perform_now(invocation.id, SubAgents::CreateTask.name, @role.id, { "intent" => "delegate" }, @role_run.id)
    ensure
      unstub_runner
    end

    assert invocation.reload.completed?
  end

  test "runner exception is propagated and invocation is marked failed" do
    invocation = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task")

    SubAgents::Runner.define_singleton_method(:new) do
      fake = Object.new
      fake.define_singleton_method(:run) { |_sub_agent, invocation: nil| raise "boom" }
      fake
    end

    begin
      assert_raises(RuntimeError) do
        SubAgentJob.perform_now(invocation.id, SubAgents::CreateTask.name, @role.id, {}, @role_run.id)
      end
    ensure
      unstub_runner
    end

    assert invocation.reload.failed?
    assert_equal "boom", invocation.error_message
  end

  test "successful ReviewTask that completes its root enqueues a summarize follow-up job" do
    root = Task.create!(title: "Root", project: @project, creator: roles(:ceo), assignee: @role, status: :in_progress)
    subtask = Task.create!(title: "Sub", project: @project, creator: @role, assignee: @role, parent_task: root, status: :completed)

    invocation = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "review_task")

    stub_runner(result: { status: "ok", summary: "approved" })
    begin
      assert_enqueued_with(job: SubAgentJob) do
        SubAgentJob.perform_now(invocation.id, SubAgents::ReviewTask.name, @role.id, { "task_id" => subtask.id }, @role_run.id)
      end
    ensure
      unstub_runner
    end

    chained = SubAgentInvocation.where(sub_agent_name: "summarize_task").order(:id).last
    assert chained, "expected a queued summarize invocation"
    assert chained.queued?
  end

  test "successful ReviewTask with incomplete siblings does not chain summarize" do
    root = Task.create!(title: "Root", project: @project, creator: roles(:ceo), assignee: @role, status: :in_progress)
    subtask = Task.create!(title: "Sub", project: @project, creator: @role, assignee: @role, parent_task: root, status: :completed)
    Task.create!(title: "Sibling", project: @project, creator: @role, assignee: @role, parent_task: root, status: :in_progress)

    invocation = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "review_task")

    stub_runner(result: { status: "ok" })
    begin
      assert_no_enqueued_jobs(only: SubAgentJob) do
        SubAgentJob.perform_now(invocation.id, SubAgents::ReviewTask.name, @role.id, { "task_id" => subtask.id }, @role_run.id)
      end
    ensure
      unstub_runner
    end

    assert_nil SubAgentInvocation.find_by(sub_agent_name: "summarize_task")
  end

  test "failed ReviewTask does not chain summarize" do
    root = Task.create!(title: "Root", project: @project, creator: roles(:ceo), assignee: @role, status: :in_progress)
    subtask = Task.create!(title: "Sub", project: @project, creator: @role, assignee: @role, parent_task: root, status: :completed)

    invocation = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "review_task")

    stub_runner(result: { status: "error", error: "nope" })
    begin
      assert_no_enqueued_jobs(only: SubAgentJob) do
        SubAgentJob.perform_now(invocation.id, SubAgents::ReviewTask.name, @role.id, { "task_id" => subtask.id }, @role_run.id)
      end
    ensure
      unstub_runner
    end
  end
end
