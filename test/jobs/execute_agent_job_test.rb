require "test_helper"
require "webmock/minitest"

class ExecuteRoleJobTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @task = tasks(:design_homepage)
    @project = projects(:acme)
    # Prevent real tmux sessions — specific adapter tests override as needed.
    # Raise like the real method does on failure so the job's rescue marks the run as failed.
    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| raise ClaudeLocalAdapter::ExecutionError, "tmux spawn failed: stub" }
  end

  teardown do
    if ClaudeLocalAdapter.singleton_class.method_defined?(:spawn_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:spawn_session)
    end
  end

  test "job is enqueued to execution queue" do
    assert_equal "execution", ExecuteRoleJob.new.queue_name
  end

  test "skips when role_run not found" do
    assert_nothing_raised do
      ExecuteRoleJob.perform_now(999999)
    end
  end

  test "skips terminal role_runs" do
    run = role_runs(:completed_run)
    ExecuteRoleJob.perform_now(run.id)
    assert run.reload.completed?
  end

  test "transitions role_run from queued to running" do
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload

    assert run.failed?
    assert run.error_message.present?
  end

  test "role returns to idle after execution failure" do
    @role.update!(status: :idle)
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    @role.reload

    assert @role.idle?, "Role should return to idle after failed execution, got #{@role.status}"
  end

  test "role_run is marked failed with error message on exception" do
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload

    assert run.failed?
    assert run.error_message.present?
    assert run.completed_at.present?
    assert_equal 1, run.exit_code
  end

  test "build_context includes task details when task present" do
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    assert_equal run.id, context[:run_id]
    assert_equal "task_assigned", context[:trigger_type]
    assert_equal @task.id, context[:task_id]
    assert_equal @task.title, context[:task_title]
  end

  test "build_context includes resume_session_id when role has prior session" do
    RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :completed, trigger_type: "scheduled",
      claude_session_id: "sess_prior_123",
      started_at: 1.hour.ago, completed_at: 30.minutes.ago
    )

    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    assert_equal "sess_prior_123", context[:resume_session_id]
  end

  test "build_context omits resume_session_id when no prior session" do
    run = RoleRun.create!(
      role: roles(:developer), task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, roles(:developer), run)

    assert_nil context[:resume_session_id]
  end

  test "skips already completed role_run" do
    run = role_runs(:completed_run)
    original_status = run.status

    ExecuteRoleJob.perform_now(run.id)
    assert_equal original_status, run.reload.status
  end

  test "skips already failed role_run" do
    run = role_runs(:failed_run)
    original_error = run.error_message

    ExecuteRoleJob.perform_now(run.id)
    assert_equal original_error, run.reload.error_message
  end

  # ---------------------------------------------------------------------------
  # Goal-scoped session resumption and goal context
  # ---------------------------------------------------------------------------

  test "build_context uses task-scoped session resumption" do
    task_a = tasks(:design_homepage)  # goal: acme_objective_one
    task_b = tasks(:fix_login_bug)    # goal: acme_objective_one (same goal)

    # Create a completed run for task_a with a session
    RoleRun.create!(
      role: @role, task: task_a, project: @project,
      status: :completed, trigger_type: "task_assigned",
      claude_session_id: "sess_goal_a", completed_at: 2.hours.ago
    )
    # Create a more recent completed run for an unrelated task (no goal)
    unrelated_task = Task.create!(title: "Unrelated", project: @project, status: :open)
    RoleRun.create!(
      role: @role, task: unrelated_task, project: @project,
      status: :completed, trigger_type: "task_assigned",
      claude_session_id: "sess_unrelated_latest", completed_at: 1.hour.ago
    )

    # New run for task_b (same goal as task_a)
    run = RoleRun.create!(
      role: @role, task: task_b, project: @project,
      status: :queued, trigger_type: "mention"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    # Should pick the session from the same goal (task_a), not the latest global one
    assert_equal "sess_goal_a", context[:resume_session_id]
  end

  test "build_context includes goal context when task has a goal" do
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    goal = @task.goal
    assert_equal goal.id, context[:goal_id]
    assert_equal goal.title, context[:goal_title]
    assert_equal goal.description, context[:goal_description]
  end

  test "build_context omits goal context when task has no goal" do
    task_no_goal = Task.create!(title: "No goal task", project: @project, status: :open)
    run = RoleRun.create!(
      role: @role, task: task_no_goal, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    assert_nil context[:goal_id]
    assert_nil context[:goal_title]
  end

  test "build_context uses global session for heartbeats with no task" do
    RoleRun.create!(
      role: @role, task: nil, project: @project,
      status: :completed, trigger_type: "scheduled",
      claude_session_id: "sess_heartbeat_global", completed_at: 1.hour.ago
    )

    run = RoleRun.create!(
      role: @role, task: nil, project: @project,
      status: :queued, trigger_type: "scheduled"
    )

    job = ExecuteRoleJob.new
    context = job.send(:build_context, @role, run)

    assert_equal "sess_heartbeat_global", context[:resume_session_id]
  end

  # ---------------------------------------------------------------------------
  # HTTP adapter end-to-end integration tests
  # ---------------------------------------------------------------------------

  test "executes HTTP role run successfully through adapter" do
    http_role = roles(:developer)
    stub_request(:post, "https://api.example.com/agent")
      .to_return(status: 200, body: '{"status":"ok"}')
    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }

    run = RoleRun.create!(
      role: http_role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload
    http_role.reload

    assert run.completed?, "Run should be completed, got #{run.status}"
    assert http_role.idle?, "Role should be idle, got #{http_role.status}"
    assert_equal 0, run.exit_code
  ensure
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end

  test "HTTP adapter 4xx marks run as failed" do
    http_role = roles(:developer)
    stub_request(:post, "https://api.example.com/agent")
      .to_return(status: 404, body: "Not Found")
    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }

    run = RoleRun.create!(
      role: http_role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload
    http_role.reload

    assert run.failed?, "Run should be failed, got #{run.status}"
    assert_match(/404/, run.error_message)
    assert http_role.idle?, "Role should return to idle, got #{http_role.status}"
  ensure
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end

  # ---------------------------------------------------------------------------
  # Claude Local adapter end-to-end integration tests
  # ---------------------------------------------------------------------------

  test "executes Claude Local role run successfully through adapter" do
    ENV["ANTHROPIC_API_KEY"] = "test_key_job"
    ClaudeLocalAdapter.define_singleton_method(:poll_sleep) { |_n| nil }

    poll_count = 0
    result_event = '{"type":"result","subtype":"success","session_id":"sess_job_abc","total_cost_usd":0.05,"result":"Done"}'
    pane_output = '{"type":"assistant","message":{"content":[{"type":"text","text":"Hi"}]}}' + "\n" + result_event

    ClaudeLocalAdapter.define_singleton_method(:spawn_session) { |_cmd| true }
    ClaudeLocalAdapter.define_singleton_method(:pane_alive?) do |_name|
      poll_count += 1
      poll_count <= 1
    end
    ClaudeLocalAdapter.define_singleton_method(:capture_pane) { |_name| pane_output }
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |_name| true }

    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload
    @role.reload

    assert run.completed?, "Run should be completed, got #{run.status}"
    assert_equal "sess_job_abc", run.claude_session_id
    assert_equal 5, run.cost_cents
    assert @role.idle?, "Role should be idle, got #{@role.status}"
  ensure
    ENV.delete("ANTHROPIC_API_KEY")
    %i[poll_sleep spawn_session pane_alive? capture_pane kill_session].each do |m|
      if ClaudeLocalAdapter.singleton_class.method_defined?(m, false)
        ClaudeLocalAdapter.singleton_class.remove_method(m)
      end
    end
  end

  test "Claude Local adapter budget exhausted marks run as failed" do
    Task.create!(
      project: @project, assignee: @role,
      title: "Prior expensive task", status: :open,
      cost_cents: @role.budget_cents,
      created_at: Date.current.beginning_of_month + 1.hour
    )

    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload
    @role.reload

    assert run.failed?, "Run should be failed, got #{run.status}"
    assert_match(/budget/i, run.error_message)
    assert @role.idle?, "Role should return to idle, got #{@role.status}"
  end

  # ---------------------------------------------------------------------------
  # Document context tests
  # ---------------------------------------------------------------------------

  test "build_context does not include documents key" do
    role = roles(:cto)
    role_run = RoleRun.create!(
      role: role,
      project: role.project,
      status: :queued,
      trigger_type: :scheduled
    )

    job = ExecuteRoleJob.new
    ctx = job.send(:build_context, role, role_run)

    assert_not ctx.key?(:documents)
  end

  # ---------------------------------------------------------------------------
  # Skill context tests
  # ---------------------------------------------------------------------------

  test "build_context includes skills for the role" do
    role = roles(:cto)
    role_run = RoleRun.create!(
      role: role,
      project: role.project,
      status: :queued,
      trigger_type: :scheduled
    )

    job = ExecuteRoleJob.new
    ctx = job.send(:build_context, role, role_run)

    assert ctx.key?(:skills)
    skill_keys = ctx[:skills].map { |s| s[:key] }
    assert_includes skill_keys, "strategic_planning"
    assert_includes skill_keys, "code_review"

    skill = ctx[:skills].find { |s| s[:key] == "code_review" }
    assert_equal "Code Review", skill[:name]
    assert_equal "technical", skill[:category]
    assert skill[:description].present?
    assert skill[:markdown].present?
  end

  # ---------------------------------------------------------------------------
  # Throttled run drain on completion
  # ---------------------------------------------------------------------------

  test "dispatches next throttled run after successful completion" do
    @project.update!(max_concurrent_agents: 1)
    RoleRun.where(project: @project).delete_all

    http_role = roles(:developer)
    stub_request(:post, "https://api.example.com/agent")
      .to_return(status: 200, body: '{"status":"ok"}')
    HttpAdapter.define_singleton_method(:backoff_sleep) { |_n| nil }

    run = RoleRun.create!(
      role: http_role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    throttled = RoleRun.create!(
      role: @role, project: @project,
      status: :throttled, trigger_type: "scheduled"
    )

    ExecuteRoleJob.perform_now(run.id)

    throttled.reload
    assert throttled.queued?, "Throttled run should be queued after slot freed, got #{throttled.status}"
  ensure
    HttpAdapter.singleton_class.remove_method(:backoff_sleep)
  end

  # ---------------------------------------------------------------------------
  # Adapter guard
  # ---------------------------------------------------------------------------

  test "fails fast with clear error when role has no adapter configured" do
    @role.update_column(:adapter_type, nil)
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    ExecuteRoleJob.perform_now(run.id)
    run.reload

    assert run.failed?
    assert_match(/no adapter configured/i, run.error_message)
  end

  # ---------------------------------------------------------------------------
  # Failure notification and escalation
  # ---------------------------------------------------------------------------

  test "posts message to task when run fails" do
    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    assert_difference "Message.count", 1 do
      ExecuteRoleJob.perform_now(run.id)
    end

    message = @task.messages.last
    assert_equal @role, message.author
    assert_equal "comment", message.message_type
    assert_match(/session ended without completing work/i, message.body)
  end

  test "does not post message when run has no task" do
    run = RoleRun.create!(
      role: @role, task: nil, project: @project,
      status: :queued, trigger_type: "scheduled"
    )

    assert_no_difference "Message.count" do
      ExecuteRoleJob.perform_now(run.id)
    end
  end

  test "escalates to manager (task creator) when run fails" do
    creator = @task.creator
    assert creator.present?, "Task must have a creator for this test"

    run = RoleRun.create!(
      role: @role, task: @task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    assert_difference "HeartbeatEvent.count" do
      ExecuteRoleJob.perform_now(run.id)
    end

    event = HeartbeatEvent.last
    assert_equal creator, event.role
    assert_equal "task_assigned", event.trigger_type
  end

  test "does not escalate when failing role is the task creator" do
    self_task = Task.create!(
      title: "Self-created task",
      project: @project,
      creator: @role,
      assignee: @role,
      status: :in_progress
    )
    run = RoleRun.create!(
      role: @role, task: self_task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    assert_no_difference "HeartbeatEvent.count" do
      ExecuteRoleJob.perform_now(run.id)
    end

    # The failure comment is still posted — we want the record on the task.
    assert run.reload.failed?
    assert_match(/session ended without completing work/i, self_task.messages.last.body)
  end

  test "does not escalate when task is already terminal" do
    done_task = tasks(:completed_task)
    run = RoleRun.create!(
      role: @role, task: done_task, project: @project,
      status: :queued, trigger_type: "task_assigned"
    )

    assert_no_difference "HeartbeatEvent.count" do
      ExecuteRoleJob.perform_now(run.id)
    end

    assert run.reload.failed?
  end

  test "dispatches next throttled run after failure" do
    @project.update!(max_concurrent_agents: 1)
    RoleRun.where(project: @project).delete_all

    run = RoleRun.create!(
      role: @role, task: nil, project: @project,
      status: :queued, trigger_type: "scheduled"
    )

    throttled = RoleRun.create!(
      role: roles(:developer), project: @project,
      status: :throttled, trigger_type: "scheduled"
    )

    ExecuteRoleJob.perform_now(run.id)

    assert run.reload.failed?
    throttled.reload
    assert throttled.queued?, "Throttled run should be queued after failed run frees slot, got #{throttled.status}"
  end
end
