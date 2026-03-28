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

    # Will fail because ClaudeLocalAdapter raises ExecutionError (missing API key),
    # but mark_running! is called before dispatch so the run transitions through running.
    ExecuteAgentJob.perform_now(run.id)
    run.reload

    # Run should be failed (adapter raises ExecutionError about missing API key)
    assert run.failed?
    assert run.error_message.present?
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

  # ---------------------------------------------------------------------------
  # Claude Local adapter end-to-end integration tests
  # ---------------------------------------------------------------------------

  test "executes Claude Local agent run successfully through adapter" do
    ENV["ANTHROPIC_API_KEY"] = "test_key_job"
    ClaudeLocalAdapter.define_singleton_method(:poll_sleep) { |_n| nil }

    poll_count = 0
    result_event = '{"type":"result","subtype":"success","session_id":"sess_job_abc","total_cost_usd":0.05,"result":"Done"}'
    pane_output = '{"type":"assistant","message":{"content":[{"type":"text","text":"Hi"}]}}' + "\n" + result_event

    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| true }
    ClaudeLocalAdapter.define_singleton_method(:session_exists?) do |_name|
      poll_count += 1
      poll_count <= 1
    end
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| pane_output }
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |_name| true }

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    run.reload
    @agent.reload

    assert run.completed?, "Run should be completed, got #{run.status}"
    assert_equal "sess_job_abc", run.claude_session_id
    assert_equal 5, run.cost_cents  # 0.05 * 100 = 5
    assert @agent.idle?, "Agent should be idle, got #{@agent.status}"
  ensure
    ENV.delete("ANTHROPIC_API_KEY")
    %i[poll_sleep spawn_session session_exists? capture_pane kill_session].each do |m|
      if ClaudeLocalAdapter.singleton_class.method_defined?(m, false)
        ClaudeLocalAdapter.singleton_class.remove_method(m)
      end
    end
  end

  test "Claude Local adapter budget exhausted marks run as failed" do
    # Exhaust the agent's budget (budget_cents: 50000) by creating a costly task assigned to it.
    Task.create!(
      company: @company, assignee: @agent,
      title: "Prior expensive task", status: :open,
      cost_cents: @agent.budget_cents,
      created_at: Date.current.beginning_of_month + 1.hour
    )

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteAgentJob.perform_now(run.id)
    run.reload
    @agent.reload

    assert run.failed?, "Run should be failed, got #{run.status}"
    assert_match(/budget/i, run.error_message)
    assert @agent.idle?, "Agent should return to idle, got #{@agent.status}"
  end
end
