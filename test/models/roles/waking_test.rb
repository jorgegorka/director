require "test_helper"

class Roles::WakingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @developer = roles(:developer)
    @process_role = roles(:process_role)
    @cto = roles(:cto)
    # Clear active fixture runs so the idempotency guard doesn't block test dispatches
    RoleRun.active.delete_all
  end

  test "creates heartbeat event for http role with delivered status" do
    event = Roles::Waking.call(
      role: @developer,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )
    assert event.persisted?
    assert event.delivered?
    assert event.scheduled?
    assert_equal "schedule", event.trigger_source
    assert event.delivered_at.present?
  end

  test "creates heartbeat event for process role with queued status" do
    event = Roles::Waking.call(
      role: @process_role,
      trigger_type: :task_assigned,
      trigger_source: "Task#42"
    )
    assert event.persisted?
    assert event.queued?
    assert event.task_assigned?
    assert_equal "Task#42", event.trigger_source
  end

  test "creates heartbeat event for claude_local role with queued status" do
    event = Roles::Waking.call(
      role: @cto,
      trigger_type: :mention,
      trigger_source: "Message#7"
    )
    assert event.persisted?
    assert event.queued?
    assert event.mention?
  end

  test "updates role last_heartbeat_at" do
    assert_changes -> { @developer.reload.last_heartbeat_at } do
      Roles::Waking.call(role: @developer, trigger_type: :scheduled)
    end
  end

  test "returns nil for terminated role" do
    @developer.update_column(:status, Role.statuses[:terminated])
    result = Roles::Waking.call(role: @developer, trigger_type: :scheduled)
    assert_nil result
  end

  test "marks event failed for role with no adapter configured and no ancestors with adapter" do
    @developer.ancestors.each { |a| a.update_column(:adapter_type, nil) }
    @developer.update_column(:adapter_type, nil)
    event = Roles::Waking.call(role: @developer.reload, trigger_type: :scheduled)

    assert event.persisted?
    assert event.failed?
    assert_match(/no adapter/i, event.metadata["error"])
  end

  test "does not create RoleRun for role with no adapter and no ancestors with adapter" do
    @developer.ancestors.each { |a| a.update_column(:adapter_type, nil) }
    @developer.update_column(:adapter_type, nil)
    assert_no_difference -> { RoleRun.count } do
      Roles::Waking.call(role: @developer.reload, trigger_type: :scheduled)
    end
  end

  test "inherits adapter from parent when role has no adapter configured" do
    parent = @developer.parent
    parent.update!(adapter_type: :claude_local, adapter_config: { "model" => "sonnet" })
    @developer.update_columns(adapter_type: nil, adapter_config: {})

    Roles::Waking.call(role: @developer.reload, trigger_type: :scheduled)

    @developer.reload
    assert_equal "claude_local", @developer.adapter_type
    assert_equal({ "model" => "sonnet" }, @developer.adapter_config)
  end

  test "request_payload includes trigger context" do
    event = Roles::Waking.call(
      role: @developer,
      trigger_type: :task_assigned,
      trigger_source: "Task#99",
      context: { task_id: 99, task_title: "Do something" }
    )
    assert_equal "task_assigned", event.request_payload["trigger"]
    assert_equal 99, event.request_payload["task_id"]
    assert_equal "Do something", event.request_payload["task_title"]
    assert_equal @developer.id, event.request_payload["role_id"]
  end

  test "increments heartbeat_event count" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      Roles::Waking.call(role: @developer, trigger_type: :scheduled)
    end
  end

  # --- RoleRun creation ---

  test "creates RoleRun record when waking role" do
    assert_difference -> { RoleRun.count }, 1 do
      Roles::Waking.call(
        role: @developer,
        trigger_type: :task_assigned,
        trigger_source: "Task#99",
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end

    run = RoleRun.last
    assert run.queued?
    assert_equal @developer, run.role
    assert_equal tasks(:fix_login_bug), run.task
    assert_equal @developer.project_id, run.project_id
    assert_equal "task_assigned", run.trigger_type
  end

  test "creates RoleRun with nil task for taskless triggers" do
    Roles::Waking.call(
      role: @cto,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )

    run = RoleRun.last
    assert run.queued?
    assert_nil run.task
    assert_equal "scheduled", run.trigger_type
  end

  test "enqueues ExecuteRoleJob when waking role" do
    assert_enqueued_with(job: ExecuteRoleJob, queue: "execution") do
      Roles::Waking.call(
        role: @developer,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end
  end

  test "creates both HeartbeatEvent and RoleRun" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      assert_difference -> { RoleRun.count }, 1 do
        Roles::Waking.call(
          role: @developer,
          trigger_type: :task_assigned,
          context: { task_id: tasks(:fix_login_bug).id }
        )
      end
    end
  end

  test "does not create RoleRun for terminated role" do
    @developer.update_column(:status, Role.statuses[:terminated])
    assert_no_difference -> { RoleRun.count } do
      Roles::Waking.call(role: @developer, trigger_type: :scheduled)
    end
  end

  test "handles string task_id from context" do
    Roles::Waking.call(
      role: @developer,
      trigger_type: :task_assigned,
      context: { "task_id" => tasks(:fix_login_bug).id.to_s }
    )

    run = RoleRun.last
    assert_equal tasks(:fix_login_bug), run.task
  end

  # --- Task wake on busy role ---

  test "creates throttled RoleRun when task assigned to busy role" do
    active_run = @cto.role_runs.create!(
      project: @cto.project, status: :running, trigger_type: "scheduled"
    )

    assert_no_enqueued_jobs(only: ExecuteRoleJob) do
      assert_difference -> { RoleRun.count }, 1 do
        Roles::Waking.call(
          role: @cto,
          trigger_type: :task_assigned,
          trigger_source: "Task#99",
          context: { task_id: tasks(:fix_login_bug).id, task_title: "Fix bug" }
        )
      end
    end

    throttled_run = RoleRun.last
    assert throttled_run.throttled?, "Run should be throttled, got #{throttled_run.status}"
    assert_equal tasks(:fix_login_bug), throttled_run.task
    assert_equal @cto, throttled_run.role
  end

  test "scheduled wake on busy role does not create throttled RoleRun" do
    @cto.role_runs.create!(
      project: @cto.project, status: :running, trigger_type: "scheduled"
    )

    assert_no_difference -> { RoleRun.count } do
      Roles::Waking.call(
        role: @cto,
        trigger_type: :scheduled,
        trigger_source: "schedule"
      )
    end
  end

  # --- Project concurrency throttling ---

  test "creates throttled run when project concurrency limit reached" do
    project = @developer.project
    project.update!(max_concurrent_agents: 1)
    # Create an active run on a different role
    other_role = roles(:cto)
    other_role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")

    assert_no_enqueued_jobs(only: ExecuteRoleJob) do
      Roles::Waking.call(
        role: @developer,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end

    run = RoleRun.last
    assert run.throttled?, "Run should be throttled, got #{run.status}"
    assert_equal @developer, run.role
  end

  test "creates queued run when project concurrency limit not reached" do
    project = @developer.project
    project.update!(max_concurrent_agents: 5)

    assert_enqueued_with(job: ExecuteRoleJob) do
      Roles::Waking.call(
        role: @developer,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end

    run = RoleRun.last
    assert run.queued?, "Run should be queued, got #{run.status}"
  end

  # --- Terminal task guard ---

  test "does not create RoleRun when task is already completed" do
    done_task = tasks(:completed_task)
    assert done_task.terminal?

    assert_no_difference -> { RoleRun.count } do
      assert_no_enqueued_jobs(only: ExecuteRoleJob) do
        Roles::Waking.call(
          role: @cto,
          trigger_type: :task_assigned,
          trigger_source: "Task##{done_task.id}",
          context: { task_id: done_task.id, task_title: done_task.title }
        )
      end
    end
  end

  test "marks heartbeat event delivered with skipped_terminal_task response for terminal task" do
    done_task = tasks(:completed_task)

    event = Roles::Waking.call(
      role: @cto,
      trigger_type: :task_assigned,
      trigger_source: "Task##{done_task.id}",
      context: { task_id: done_task.id, task_title: done_task.title }
    )

    assert event.persisted?
    assert event.delivered?
    assert_equal "skipped_terminal_task", event.response_payload["status"]
  end


  test "creates queued run when project concurrency limit is zero (unlimited)" do
    project = @developer.project
    project.update!(max_concurrent_agents: 0)

    assert_enqueued_with(job: ExecuteRoleJob) do
      Roles::Waking.call(
        role: @developer,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end

    run = RoleRun.last
    assert run.queued?
  end
end
