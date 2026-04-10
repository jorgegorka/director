require "test_helper"

class Tools::ReviewTaskAgentTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @task = tasks(:fix_login_bug)
    @task.update_columns(status: Task.statuses[:pending_review])

    @root = Task.create!(
      title: "Root mission",
      project: @task.project,
      creator: roles(:ceo),
      assignee: @role,
      status: :in_progress
    )
    @task.update_columns(parent_task_id: @root.id)

    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id, status: RoleRun.statuses[:running])
  end

  # Build a ReviewTaskAgent whose super#call (the review sub-agent spawn) is
  # stubbed out, and intercept SummarizeTask.new to detect whether
  # auto-summarization fires.
  def build_tool(summarize_spy:)
    tool = Tools::ReviewTaskAgent.new(@role)

    review_result = { status: "ok", sub_agent: "review_task", summary: "Approved.", cost_cents: 1 }

    fake_sub_agent = Object.new
    fake_sub_agent.define_singleton_method(:call) { review_result }

    original_new = SubAgents::ReviewTask.method(:new)
    SubAgents::ReviewTask.define_singleton_method(:new) { |**_kwargs| fake_sub_agent }

    summarize_result = { status: "ok", summary: "Task summarized." }
    original_summarize_new = SubAgents::SummarizeTask.method(:new)
    SubAgents::SummarizeTask.define_singleton_method(:new) do |**kwargs|
      summarize_spy[:called] = true
      summarize_spy[:arguments] = kwargs[:arguments]
      fake = Object.new
      fake.define_singleton_method(:call) { summarize_result }
      fake
    end

    cleanup = -> {
      SubAgents::ReviewTask.define_singleton_method(:new, original_new)
      SubAgents::SummarizeTask.define_singleton_method(:new, original_summarize_new)
    }

    [ tool, cleanup ]
  end

  test "auto-summarizes root task when approval completes all subtasks" do
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert spy[:called], "SummarizeTask sub-agent should have been triggered"
    assert_equal @root.id, spy[:arguments]["task_id"]
  end

  test "does not auto-summarize when root has remaining incomplete subtasks" do
    Task.create!(title: "Sibling still running", project: @task.project, creator: @role, assignee: @role, parent_task: @root, status: :in_progress)
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeTask should not be triggered when root has incomplete subtasks"
  end

  test "does not auto-summarize when root already has a summary" do
    @task.update_columns(status: Task.statuses[:completed])
    @root.update_columns(summary: "Already summarized.")

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeTask should not be triggered when summary already exists"
  end

  test "does not auto-summarize when task has no parent (is itself a root)" do
    @task.update_columns(parent_task_id: nil, status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeTask should not be triggered for a root task"
  end

  test "includes root_task_summarized in result when summarization happens" do
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      result = tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert_equal @root.id, result[:root_task_summarized]
  end

  test "does not include root_task_summarized when no summarization needed" do
    Task.create!(title: "Sibling still running", project: @task.project, creator: @role, assignee: @role, parent_task: @root, status: :in_progress)
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      result = tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert_nil result[:root_task_summarized]
  end
end
