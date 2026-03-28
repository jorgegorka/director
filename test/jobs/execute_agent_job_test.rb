require "test_helper"
require "webmock/minitest"

class ExecuteAgentJobTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude_agent)
    @task = tasks(:design_homepage)
    @company = companies(:acme)
  end

  test "job is enqueued to execution queue" do
    assert_equal "execution", ExecuteAgentJob.new.queue_name
  end

  test "skips when agent_run not found" do
    assert_nothing_raised do
      ExecuteAgentJob.perform_now(999999)
    end
  end

  test "skips terminal agent_runs" do
    run = agent_runs(:completed_run)
    # Should not change anything
    ExecuteAgentJob.perform_now(run.id)
    assert run.reload.completed?
  end

  test "transitions agent_run from queued to running" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    # Will fail because adapter raises NotImplementedError, but
    # the mark_running! call happens before dispatch
    ExecuteAgentJob.perform_now(run.id)
    run.reload

    # Run should be failed (adapter not implemented yet)
    assert run.failed?
    assert_match(/NotImplementedError|must implement/, run.error_message)
  end

  test "agent returns to idle after execution failure" do
    @agent.update!(status: :idle)
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    @agent.reload

    assert @agent.idle?, "Agent should return to idle after failed execution, got #{@agent.status}"
  end

  test "agent_run is marked failed with error message on exception" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    run.reload

    assert run.failed?
    assert run.error_message.present?
    assert run.completed_at.present?
    assert_equal 1, run.exit_code
  end

  test "build_context includes task details when task present" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteAgentJob.new
    context = job.send(:build_context, @agent, run)

    assert_equal run.id, context[:run_id]
    assert_equal "task_assigned", context[:trigger_type]
    assert_equal @task.id, context[:task_id]
    assert_equal @task.title, context[:task_title]
  end

  test "build_context includes resume_session_id when agent has prior session" do
    # Create a completed run with session ID
    AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :completed, trigger_type: "scheduled",
      claude_session_id: "sess_prior_123",
      started_at: 1.hour.ago, completed_at: 30.minutes.ago
    )

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteAgentJob.new
    context = job.send(:build_context, @agent, run)

    assert_equal "sess_prior_123", context[:resume_session_id]
  end

  test "build_context omits resume_session_id when no prior session" do
    run = AgentRun.create!(
      agent: agents(:http_agent), task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteAgentJob.new
    context = job.send(:build_context, agents(:http_agent), run)

    assert_nil context[:resume_session_id]
  end

  test "skips already completed agent_run" do
    run = agent_runs(:completed_run)
    original_status = run.status

    ExecuteAgentJob.perform_now(run.id)
    assert_equal original_status, run.reload.status
  end

  test "skips already failed agent_run" do
    run = agent_runs(:failed_run)
    original_error = run.error_message

    ExecuteAgentJob.perform_now(run.id)
    assert_equal original_error, run.reload.error_message
  end

  # ---------------------------------------------------------------------------
  # HTTP adapter end-to-end integration tests
  # ---------------------------------------------------------------------------

  test "executes HTTP agent run successfully through adapter" do
    http_agent = agents(:http_agent)
    stub_request(:post, "https://api.example.com/agent")
      .to_return(status: 200, body: '{"status":"ok"}')
    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }

    run = AgentRun.create!(
      agent: http_agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    run.reload
    http_agent.reload

    assert run.completed?, "Run should be completed, got #{run.status}"
    assert http_agent.idle?, "Agent should be idle, got #{http_agent.status}"
    assert_equal 0, run.exit_code
  ensure
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end

  test "HTTP adapter 4xx marks run as failed" do
    http_agent = agents(:http_agent)
    stub_request(:post, "https://api.example.com/agent")
      .to_return(status: 404, body: "Not Found")
    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }

    run = AgentRun.create!(
      agent: http_agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    run.reload
    http_agent.reload

    assert run.failed?, "Run should be failed, got #{run.status}"
    assert_match(/404/, run.error_message)
    assert http_agent.idle?, "Agent should return to idle, got #{http_agent.status}"
  ensure
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end
end
