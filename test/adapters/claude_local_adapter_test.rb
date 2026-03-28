require "test_helper"

class ClaudeLocalAdapterTest < ActiveSupport::TestCase
  RESULT_EVENT = '{"type":"result","subtype":"success","session_id":"sess_new_xyz","total_cost_usd":0.0234,"result":"Task complete"}'
  ASSISTANT_EVENT = '{"type":"assistant","message":{"content":[{"type":"text","text":"Done"}]}}'

  setup do
    @agent   = agents(:claude_agent)
    @task    = tasks(:design_homepage)
    @company = companies(:acme)
    @context = {
      run_id: nil,  # set per test after creating AgentRun
      trigger_type: "task_assigned",
      task_id: @task.id,
      task_title: @task.title,
      task_description: @task.description
    }

    # Global baseline: disable all real shell-outs and real sleep.
    # Individual tests override these as needed.
    # Local variables are used to capture state because define_singleton_method
    # blocks run with self = the class, so @instance_vars would refer to the class, not the test.
    ENV["ANTHROPIC_API_KEY"] = "test_key_baseline"
    spawn_calls = @spawn_calls = []
    kill_calls  = @kill_calls  = []
    poll_count  = 0

    ClaudeLocalAdapter.define_singleton_method(:poll_sleep) { |_n| nil }
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |cmd| spawn_calls << cmd; true }
    ClaudeLocalAdapter.define_singleton_method(:session_exists?) do |_name|
      poll_count += 1
      poll_count <= 1  # session exists for 1 poll then gone
    end
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) do |_name|
      ASSISTANT_EVENT + "\n" + RESULT_EVENT
    end
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |name| kill_calls << name; true }
  end

  teardown do
    ENV.delete("ANTHROPIC_API_KEY")
    # Remove singleton overrides added in setup (and any added per-test).
    # Note: env_prefix is NOT in this list since it uses the real method + ENV.
    # Tests that override env_prefix must restore it manually in their ensure block.
    %i[poll_sleep spawn_session session_exists? capture_pane kill_session].each do |m|
      if ClaudeLocalAdapter.singleton_class.method_defined?(m, false)
        ClaudeLocalAdapter.singleton_class.remove_method(m)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-06: Budget gate
  # ---------------------------------------------------------------------------

  # CLAUDE-06: exhausted budget blocks execution without spawning tmux
  test "budget exhausted raises BudgetExhausted without spawning tmux" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    # Stub budget_exhausted? on the agent instance
    @agent.define_singleton_method(:budget_exhausted?) { true }

    spawn_called = false
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| spawn_called = true; true }

    assert_raises(ClaudeLocalAdapter::BudgetExhausted) do
      ClaudeLocalAdapter.execute(@agent, @context)
    end

    assert_equal false, spawn_called, "spawn_session must not be called when budget exhausted"
  ensure
    @agent.singleton_class.remove_method(:budget_exhausted?) if @agent.singleton_class.method_defined?(:budget_exhausted?, false)
  end

  # CLAUDE-06: budget OK allows execution to proceed
  test "budget OK allows execution to proceed" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    result = nil
    assert_nothing_raised do
      result = ClaudeLocalAdapter.execute(@agent, @context)
    end

    assert result.is_a?(Hash), "Expected result hash"
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-01: tmux command construction and session management
  # ---------------------------------------------------------------------------

  # CLAUDE-01: spawn command includes --bare flag
  test "tmux command includes --bare flag" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--bare") }, "spawn command should include --bare"
  end

  # CLAUDE-07: ANTHROPIC_API_KEY is passed in env prefix
  test "tmux command includes ANTHROPIC_API_KEY in environment" do
    ENV["ANTHROPIC_API_KEY"] = "test_key_123"

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("ANTHROPIC_API_KEY") && cmd.include?("test_key_123") },
      "spawn command should include ANTHROPIC_API_KEY"
  end

  # CLAUDE-01: spawn command includes --output-format stream-json
  test "tmux command includes --output-format stream-json" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--output-format stream-json") }
  end

  # CLAUDE-01: spawn command includes --model from adapter_config
  test "tmux command includes --model from adapter_config" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--model claude-sonnet-4-20250514") }
  end

  # CLAUDE-01: session name uses run_id
  test "tmux session name uses run_id" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("director_run_#{run.id}") }
  end

  # max_turns from config passed to claude command
  test "tmux command includes --max-turns when configured" do
    @agent.adapter_config["max_turns"] = 5

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--max-turns 5") }
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-04: --resume flag
  # ---------------------------------------------------------------------------

  # CLAUDE-04: --resume included when resume_session_id present
  test "tmux command includes --resume when resume_session_id present" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:resume_session_id] = "sess_prior_abc"
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--resume sess_prior_abc") }
  end

  # CLAUDE-04: --resume omitted when no resume_session_id
  test "tmux command omits --resume when no resume_session_id" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context.delete(:resume_session_id)
    ClaudeLocalAdapter.execute(@agent, @context)

    assert @spawn_calls.none? { |cmd| cmd.include?("--resume") }
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-02: Stream-JSON log accumulation
  # ---------------------------------------------------------------------------

  # CLAUDE-02: stream-JSON lines accumulated in AgentRun log
  test "stream-JSON lines accumulated in AgentRun log" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@agent, @context)

    run.reload
    assert run.log_output.include?(ASSISTANT_EVENT), "log_output should contain assistant event"
    assert run.log_output.include?(RESULT_EVENT), "log_output should contain result event"
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-03: Session ID extraction
  # ---------------------------------------------------------------------------

  # CLAUDE-03: session_id extracted from result event
  test "session_id extracted from result event" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@agent, @context)

    assert_equal "sess_new_xyz", result[:session_id]
  end

  # CLAUDE-03 / CLAUDE-05: missing result event returns nil session_id and cost_cents
  test "missing result event returns nil session_id and cost_cents" do
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| ASSISTANT_EVENT }

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@agent, @context)

    assert_nil result[:session_id]
    assert_nil result[:cost_cents]
  end

  # ---------------------------------------------------------------------------
  # CLAUDE-05: Cost conversion
  # ---------------------------------------------------------------------------

  # CLAUDE-05: cost_cents converted from total_cost_usd (0.0234 * 100 = 2.34 -> rounds to 2)
  test "cost_cents converted from total_cost_usd" do
    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@agent, @context)

    assert_equal 2, result[:cost_cents]
  end

  # CLAUDE-05: cost_cents conversion handles larger amounts with rounding (1.5678 * 100 = 156.78 -> 157)
  test "cost_cents conversion handles larger amounts" do
    large_result = '{"type":"result","subtype":"success","session_id":"sess_large","total_cost_usd":1.5678,"result":"Done"}'
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| ASSISTANT_EVENT + "\n" + large_result }

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@agent, @context)

    assert_equal 157, result[:cost_cents]
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  # CLAUDE-01: tmux session failure raises ExecutionError
  test "tmux session failure raises ExecutionError" do
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| false }

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@agent, @context)
    end

    assert_match(/failed to create tmux session/i, error.message)
  end

  # CLAUDE-07: missing ANTHROPIC_API_KEY raises ExecutionError
  test "missing ANTHROPIC_API_KEY raises ExecutionError" do
    # Remove the test API key so env_prefix raises naturally.
    ENV.delete("ANTHROPIC_API_KEY")

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@agent, @context)
    end

    assert_match(/ANTHROPIC_API_KEY not configured/i, error.message)
  end

  # Ensure block cleans up tmux session even on error mid-execution
  test "ensure block cleans up tmux session on error" do
    ClaudeLocalAdapter.define_singleton_method(:session_exists?) { |_name| raise RuntimeError, "poll exploded" }

    run = AgentRun.create!(
      agent: @agent, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    assert_raises(RuntimeError) do
      ClaudeLocalAdapter.execute(@agent, @context)
    end

    expected_session = "director_run_#{run.id}"
    assert_includes @kill_calls, expected_session, "kill_session should have been called for #{expected_session}"
  end

  # ---------------------------------------------------------------------------
  # Regression: class methods unchanged
  # ---------------------------------------------------------------------------

  test "display_name, description, config_schema unchanged" do
    assert_equal "Claude Code (Local)", ClaudeLocalAdapter.display_name
    assert_equal "Run Claude CLI locally with streaming JSON output and session resumption", ClaudeLocalAdapter.description
    assert_equal %w[model], ClaudeLocalAdapter.config_schema[:required]
    assert_includes ClaudeLocalAdapter.config_schema[:optional], "max_turns"
  end
end
