require "test_helper"

class ClaudeLocalAdapterTest < ActiveSupport::TestCase
  RESULT_EVENT = '{"type":"result","subtype":"success","session_id":"sess_new_xyz","total_cost_usd":0.0234,"result":"Task complete"}'
  ASSISTANT_EVENT = '{"type":"assistant","message":{"content":[{"type":"text","text":"Done"}]}}'

  setup do
    @role    = roles(:cto)
    @task    = tasks(:design_homepage)
    @company = companies(:acme)
    @context = {
      run_id: nil,
      trigger_type: "task_assigned",
      task_id: @task.id,
      task_title: @task.title,
      task_description: @task.description
    }

    ENV["ANTHROPIC_API_KEY"] = "test_key_baseline"
    spawn_calls = @spawn_calls = []
    kill_calls  = @kill_calls  = []
    poll_count  = 0

    ClaudeLocalAdapter.define_singleton_method(:poll_sleep) { |_n| nil }
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |cmd| spawn_calls << cmd; true }
    ClaudeLocalAdapter.define_singleton_method(:session_exists?) do |_name|
      poll_count += 1
      poll_count <= 1
    end
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) do |_name|
      ASSISTANT_EVENT + "\n" + RESULT_EVENT
    end
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |name| kill_calls << name; true }
  end

  teardown do
    ENV.delete("ANTHROPIC_API_KEY")
    %i[poll_sleep spawn_session session_exists? capture_pane kill_session].each do |m|
      if ClaudeLocalAdapter.singleton_class.method_defined?(m, false)
        ClaudeLocalAdapter.singleton_class.remove_method(m)
      end
    end
  end

  test "budget exhausted raises BudgetExhausted without spawning tmux" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    @role.define_singleton_method(:budget_exhausted?) { true }

    spawn_called = false
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| spawn_called = true; true }

    assert_raises(ClaudeLocalAdapter::BudgetExhausted) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_equal false, spawn_called, "spawn_session must not be called when budget exhausted"
  ensure
    @role.singleton_class.remove_method(:budget_exhausted?) if @role.singleton_class.method_defined?(:budget_exhausted?, false)
  end

  test "budget OK allows execution to proceed" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    result = nil
    assert_nothing_raised do
      result = ClaudeLocalAdapter.execute(@role, @context)
    end

    assert result.is_a?(Hash), "Expected result hash"
  end

  test "tmux command includes --bare flag" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--bare") }, "spawn command should include --bare"
  end

  test "tmux command includes ANTHROPIC_API_KEY in environment" do
    ENV["ANTHROPIC_API_KEY"] = "test_key_123"

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("ANTHROPIC_API_KEY") && cmd.include?("test_key_123") },
      "spawn command should include ANTHROPIC_API_KEY"
  end

  test "tmux command includes --output-format stream-json" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--output-format stream-json") }
  end

  test "tmux command includes --model from adapter_config" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--model claude-sonnet-4-20250514") }
  end

  test "tmux session name uses run_id" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("director_run_#{run.id}") }
  end

  test "tmux command includes --max-turns when configured" do
    @role.adapter_config["max_turns"] = 5

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--max-turns 5") }
  end

  test "tmux command includes --resume when resume_session_id present" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:resume_session_id] = "sess_prior_abc"
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("--resume sess_prior_abc") }
  end

  test "tmux command omits --resume when no resume_session_id" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context.delete(:resume_session_id)
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.none? { |cmd| cmd.include?("--resume") }
  end

  test "stream-JSON lines accumulated in RoleRun log" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    run.reload
    assert run.log_output.include?(ASSISTANT_EVENT), "log_output should contain assistant event"
    assert run.log_output.include?(RESULT_EVENT), "log_output should contain result event"
  end

  test "session_id extracted from result event" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@role, @context)

    assert_equal "sess_new_xyz", result[:session_id]
  end

  test "missing result event returns nil session_id and cost_cents" do
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| ASSISTANT_EVENT }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@role, @context)

    assert_nil result[:session_id]
    assert_nil result[:cost_cents]
  end

  test "cost_cents converted from total_cost_usd" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@role, @context)

    assert_equal 2, result[:cost_cents]
  end

  test "cost_cents conversion handles larger amounts" do
    large_result = '{"type":"result","subtype":"success","session_id":"sess_large","total_cost_usd":1.5678,"result":"Done"}'
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| ASSISTANT_EVENT + "\n" + large_result }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@role, @context)

    assert_equal 157, result[:cost_cents]
  end

  test "tmux session failure raises ExecutionError" do
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| false }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_match(/failed to create tmux session/i, error.message)
  end

  test "missing ANTHROPIC_API_KEY raises ExecutionError" do
    ENV.delete("ANTHROPIC_API_KEY")

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_match(/ANTHROPIC_API_KEY not configured/i, error.message)
  end

  test "ensure block cleans up tmux session on error" do
    ClaudeLocalAdapter.define_singleton_method(:session_exists?) { |_name| raise RuntimeError, "poll exploded" }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    assert_raises(RuntimeError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    expected_session = "director_run_#{run.id}"
    assert_includes @kill_calls, expected_session, "kill_session should have been called for #{expected_session}"
  end

  test "system prompt includes skill catalog when skills present" do
    skills = [
      { key: "code_review", name: "Code Review", description: "Review code for quality", category: "technical", markdown: "# Code Review\n\n## Instructions\n1. Read the diff" },
      { key: "debugging", name: "Debugging", description: "Diagnose defects", category: "technical", markdown: "# Debugging\n\n## Instructions\n1. Reproduce the bug" }
    ]

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, { skills: skills })

    assert_includes prompt, "Code Review"
    assert_includes prompt, "Debugging"
    assert_includes prompt, "code_review"
    assert_includes prompt, "debugging"
    assert_includes prompt, "Your Skills"
  end

  test "system prompt omits skills section when no skills and no job spec" do
    @role.job_spec = nil

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, { skills: [] })

    assert_equal "", prompt
  end

  test "command includes --system-prompt flag when skills present" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:skills] = [
      { key: "code_review", name: "Code Review", description: "Review code", category: "technical", markdown: "# Code Review" }
    ]

    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.last.include?("--system-prompt"), "command should include --system-prompt flag"
  end

  test "command omits --system-prompt when no skills and no job spec" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:skills] = []
    @role.job_spec = nil

    ClaudeLocalAdapter.execute(@role, @context)

    assert_not @spawn_calls.last.include?("--system-prompt"), "command should not include --system-prompt"
  end

  test "system prompt combines role description with skills" do
    @role.job_spec = "You are a helpful assistant."
    skills = [
      { key: "testing", name: "Testing", description: "Write tests", category: "technical", markdown: "# Testing\n\n## Instructions\n1. Write tests" }
    ]

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, { skills: skills })

    assert_includes prompt, "You are a helpful assistant."
    assert_includes prompt, "Testing"
    assert_includes prompt, "Your Skills"
  end

  test "tmux command includes -c flag when working_directory present" do
    @role.working_directory = "/projects/website"

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("-c /projects/website") },
      "spawn command should include -c with working directory"
  end

  test "tmux command omits -c flag when working_directory nil" do
    @role.working_directory = nil

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.none? { |cmd| cmd.include?("-c ") },
      "spawn command should not include -c flag"
  end

  test "display_name, description, config_schema unchanged" do
    assert_equal "Claude Code (Local)", ClaudeLocalAdapter.display_name
    assert_equal "Run Claude CLI locally with streaming JSON output and session resumption", ClaudeLocalAdapter.description
    assert_equal %w[model], ClaudeLocalAdapter.config_schema[:required]
    assert_includes ClaudeLocalAdapter.config_schema[:optional], "max_turns"
  end
end
