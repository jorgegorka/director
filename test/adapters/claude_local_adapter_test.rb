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
    ClaudeLocalAdapter.define_singleton_method(:pane_alive?) do |_name|
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
    %i[poll_sleep spawn_session pane_alive? session_exists? capture_pane kill_session].each do |m|
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

  test "tmux command does not include --bare flag" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.none? { |cmd| cmd.include?("--bare") }, "spawn command should not include --bare (breaks Keychain auth)"
  end

  test "tmux command includes ANTHROPIC_API_KEY in environment" do
    ENV["ANTHROPIC_API_KEY"] = "test_key_123"

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.any? { |cmd| cmd.include?("-e ANTHROPIC_API_KEY=test_key_123") },
      "spawn command should include ANTHROPIC_API_KEY"
  end

  test "tmux command always forwards HOME and PATH" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    cmd = @spawn_calls.last
    assert_includes cmd, "-e HOME=", "spawn command should forward HOME"
    assert_includes cmd, "-e PATH=", "spawn command should forward PATH"
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
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) do |_cmd|
      raise ClaudeLocalAdapter::ExecutionError, "tmux spawn failed: session creation error"
    end

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_match(/tmux spawn failed/i, error.message)
  end

  test "missing ANTHROPIC_API_KEY omits it from env_flags but keeps HOME and PATH" do
    ENV.delete("ANTHROPIC_API_KEY")

    flags = ClaudeLocalAdapter.env_flags
    assert_not_includes flags, "ANTHROPIC_API_KEY"
    assert_includes flags, "-e HOME="
    assert_includes flags, "-e PATH="
  end

  test "missing ANTHROPIC_API_KEY omits it from tmux command" do
    ENV.delete("ANTHROPIC_API_KEY")

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.none? { |cmd| cmd.include?("ANTHROPIC_API_KEY") },
      "spawn command should not include ANTHROPIC_API_KEY when no API key"
  end

  test "ensure block cleans up tmux session on error" do
    ClaudeLocalAdapter.define_singleton_method(:pane_alive?) { |_name| raise RuntimeError, "poll exploded" }

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

  test "system prompt always includes identity section" do
    @role.job_spec = nil

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, { skills: [] })

    assert_includes prompt, "Your Identity"
    assert_includes prompt, @role.title
    assert_includes prompt, @role.company.name
  end

  test "command includes --system-prompt-file flag when skills present" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:skills] = [
      { key: "code_review", name: "Code Review", description: "Review code", category: "technical", markdown: "# Code Review" }
    ]

    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.last.include?("--system-prompt-file"), "command should include --system-prompt-file flag"
  end

  test "command always includes --system-prompt-file for identity context" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    @context[:skills] = []
    @role.job_spec = nil

    ClaudeLocalAdapter.execute(@role, @context)

    assert @spawn_calls.last.include?("--system-prompt-file"), "command should always include --system-prompt-file for identity"
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
    dir = Dir.mktmpdir
    @role.working_directory = dir

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    resolved = File.realpath(dir)
    assert @spawn_calls.any? { |cmd| cmd.include?("-c #{resolved}") },
      "spawn command should include -c with resolved working directory"
  ensure
    FileUtils.rm_rf(dir) if dir
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

  test "authentication_failed in assistant event raises ExecutionError" do
    auth_failed_event = '{"type":"assistant","message":{"content":[{"type":"text","text":"Not logged in"}]},"error":"authentication_failed"}'
    result_event = '{"type":"result","subtype":"success","is_error":true,"session_id":"sess_abc","total_cost_usd":0,"result":"Not logged in"}'
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| auth_failed_event + "\n" + result_event }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_match(/not authenticated/i, error.message)
  end

  test "is_error true in result event sets exit_code 1 and error_message" do
    error_result = '{"type":"result","subtype":"success","is_error":true,"session_id":"sess_err","total_cost_usd":0.01,"result":"Something went wrong"}'
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| error_result }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    result = ClaudeLocalAdapter.execute(@role, @context)

    assert_equal 1, result[:exit_code]
    assert_equal "Something went wrong", result[:error_message]
  end

  test "system prompt includes goal section when goal context present" do
    context = {
      goal_title: "Improve SEO rankings",
      goal_description: "Increase organic traffic by 30%"
    }

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, context)

    assert_includes prompt, "## Current Goal"
    assert_includes prompt, "**Improve SEO rankings**"
    assert_includes prompt, "Increase organic traffic by 30%"
  end

  test "system prompt omits goal section when no goal context" do
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, { skills: [] })

    assert_not_includes prompt, "Current Goal"
  end

  test "section ordering: identity, job_spec, category_spec, goal, skills" do
    @role.job_spec = "You are the CMO."
    context = {
      goal_title: "Improve SEO",
      skills: [
        { key: "seo", name: "SEO", description: "Optimize search", category: "marketing", markdown: "# SEO" }
      ]
    }

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, context)

    identity_pos = prompt.index("Your Identity")
    job_spec_pos = prompt.index("You are the CMO.")
    category_pos = prompt.index(@role.role_category.job_spec)
    goal_pos = prompt.index("Current Goal")
    skills_pos = prompt.index("Your Skills")

    assert identity_pos < job_spec_pos, "Identity should appear before job spec"
    assert job_spec_pos < category_pos, "Job spec should appear before category spec"
    assert category_pos < goal_pos, "Category spec should appear before goal"
    assert goal_pos < skills_pos, "Goal should appear before skills"
  end

  test "identity prompt includes subordinates" do
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, roles(:ceo), {})

    assert_includes prompt, "Your Organization"
    assert_includes prompt, "CTO"
  end

  test "identity prompt includes Director MCP tool catalog" do
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, {})

    assert_includes prompt, "Director MCP tools"
    assert_includes prompt, "create_task"
    assert_includes prompt, "hire_role"
    assert_includes prompt, "get_goal_details"
    assert_includes prompt, "update_goal"
  end

  test "goal prompt includes focus rules" do
    context = {
      goal_title: "Improve SEO rankings",
      goal_description: "Increase organic traffic by 30%"
    }

    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, context)

    assert_includes prompt, "## Focus Rules"
    assert_includes prompt, "Do NOT create new goals"
    assert_includes prompt, "Do NOT start work outside this goal"
    assert_includes prompt, "add_message"
  end

  test "user prompt includes task_id and title" do
    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id
    ClaudeLocalAdapter.execute(@role, @context)

    cmd = @spawn_calls.last
    assert_includes cmd, "Task\\ \\##{@task.id}"
    assert_includes cmd, @task.title.gsub(" ", "\\ ")
  end

  test "env_flags sets CLAUDE_CONFIG_DIR to isolated agent config directory" do
    flags = ClaudeLocalAdapter.env_flags

    assert_includes flags, "-e CLAUDE_CONFIG_DIR="
    assert_includes flags, "tmp/claude_agent_config"
    assert_not_includes flags, ".claude", "should not reference user's personal ~/.claude directory"
  end

  test "agent_config_dir creates tmp directory" do
    dir = ClaudeLocalAdapter.agent_config_dir

    assert dir.end_with?("tmp/claude_agent_config")
    assert File.directory?(dir)
  end

  test "system prompt includes job_spec with workflow when present" do
    @role.job_spec = Role::DEFAULT_JOB_SPEC
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, {})

    assert_includes prompt, "Task Workflow"
    assert_includes prompt, "update_task_status"
    assert_includes prompt, "add_message"
  end

  test "system prompt includes role_category job_spec after role job_spec" do
    @role.job_spec = "You are the CTO."
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, @role, {})

    assert_includes prompt, "You are the CTO."
    assert_includes prompt, @role.role_category.job_spec

    role_spec_pos = prompt.index("You are the CTO.")
    category_spec_pos = prompt.index(@role.role_category.job_spec)
    assert role_spec_pos < category_spec_pos, "Role job_spec should appear before category job_spec"
  end

  test "system prompt omits category job_spec when role has no category" do
    @role.instance_variable_set(:@association_cache, {})
    allow_nil_category = @role.dup
    allow_nil_category.define_singleton_method(:role_category) { nil }
    prompt = ClaudeLocalAdapter.send(:compose_system_prompt, allow_nil_category, {})

    assert_includes prompt, "Your Identity"
  end

  test "build_user_prompt includes task_id when task context present" do
    prompt = ClaudeLocalAdapter.send(:build_user_prompt, @context)

    assert_includes prompt, "Task ##{@task.id}"
    assert_includes prompt, @task.title
  end

  test "build_user_prompt falls back to goal context" do
    context = { goal_id: 1, goal_title: "Improve SEO", goal_description: "Increase traffic" }
    prompt = ClaudeLocalAdapter.send(:build_user_prompt, context)

    assert_includes prompt, "Improve SEO"
    assert_includes prompt, "list_my_tasks"
  end

  test "build_user_prompt generic fallback when no task or goal" do
    prompt = ClaudeLocalAdapter.send(:build_user_prompt, {})

    assert_includes prompt, "list_my_goals"
    assert_includes prompt, "list_my_tasks"
  end

  test "stall detection raises ExecutionError after STALL_TIMEOUT with no new output" do
    stall_clock = 0.0
    ClaudeLocalAdapter.define_singleton_method(:poll_sleep) { |_n| stall_clock += ClaudeLocalAdapter::STALL_TIMEOUT + 1 }

    # Override clock to simulate time passing during stalls
    original_clock = Process.method(:clock_gettime)
    Process.define_singleton_method(:clock_gettime) { |*_args| stall_clock }

    # pane_alive? always true so we rely on stall detection to break
    ClaudeLocalAdapter.define_singleton_method(:pane_alive?) { |_name| true }
    # Return same output every poll (no new lines)
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| ASSISTANT_EVENT }

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    error = assert_raises(ClaudeLocalAdapter::ExecutionError) do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_match(/stalled/i, error.message)
    assert_match(/#{ClaudeLocalAdapter::STALL_TIMEOUT}/, error.message)
  ensure
    Process.define_singleton_method(:clock_gettime, original_clock) if original_clock
  end

  test "stall timer resets when new output appears" do
    poll_count = 0
    ClaudeLocalAdapter.define_singleton_method(:pane_alive?) do |_name|
      poll_count += 1
      poll_count <= 3
    end
    # Return progressively more output each poll
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) do |_name|
      lines = [ ASSISTANT_EVENT ]
      lines << '{"type":"system","subtype":"progress"}' if poll_count >= 2
      lines << RESULT_EVENT if poll_count >= 3
      lines.join("\n")
    end

    run = RoleRun.create!(
      role: @role, task: @task, company: @company,
      status: :queued, trigger_type: "task_assigned"
    )
    @context[:run_id] = run.id

    result = assert_nothing_raised do
      ClaudeLocalAdapter.execute(@role, @context)
    end

    assert_equal "sess_new_xyz", result[:session_id]
  end

  test "display_name, description, config_schema unchanged" do
    assert_equal "Claude Code (Local)", ClaudeLocalAdapter.display_name
    assert_equal "Run Claude CLI locally with streaming JSON output and session resumption", ClaudeLocalAdapter.description
    assert_equal %w[model], ClaudeLocalAdapter.config_schema[:required]
    assert_includes ClaudeLocalAdapter.config_schema[:optional], "max_turns"
  end
end
