require "test_helper"

class WakeRoleServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @developer = roles(:developer)
    @process_role = roles(:process_role)
    @cto = roles(:cto)
    # Clear active fixture runs so the idempotency guard doesn't block test dispatches
    RoleRun.active.delete_all
  end

  test "creates heartbeat event for http role with delivered status" do
    event = WakeRoleService.call(
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
    event = WakeRoleService.call(
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
    event = WakeRoleService.call(
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
      WakeRoleService.call(role: @developer, trigger_type: :scheduled)
    end
  end

  test "returns nil for terminated role" do
    @developer.update_column(:status, Role.statuses[:terminated])
    result = WakeRoleService.call(role: @developer, trigger_type: :scheduled)
    assert_nil result
  end

  test "request_payload includes trigger context" do
    event = WakeRoleService.call(
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
      WakeRoleService.call(role: @developer, trigger_type: :scheduled)
    end
  end

  # --- RoleRun creation ---

  test "creates RoleRun record when waking role" do
    assert_difference -> { RoleRun.count }, 1 do
      WakeRoleService.call(
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
    assert_equal @developer.company_id, run.company_id
    assert_equal "task_assigned", run.trigger_type
  end

  test "creates RoleRun with nil task for taskless triggers" do
    WakeRoleService.call(
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
      WakeRoleService.call(
        role: @developer,
        trigger_type: :task_assigned,
        context: { task_id: tasks(:fix_login_bug).id }
      )
    end
  end

  test "creates both HeartbeatEvent and RoleRun" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      assert_difference -> { RoleRun.count }, 1 do
        WakeRoleService.call(
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
      WakeRoleService.call(role: @developer, trigger_type: :scheduled)
    end
  end

  test "handles string task_id from context" do
    WakeRoleService.call(
      role: @developer,
      trigger_type: :task_assigned,
      context: { "task_id" => tasks(:fix_login_bug).id.to_s }
    )

    run = RoleRun.last
    assert_equal tasks(:fix_login_bug), run.task
  end
end
