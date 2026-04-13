require "test_helper"

class Roles::HeartbeatsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @role = roles(:developer)
  end

  # --- sync_heartbeat_schedule via after_commit ---

  test "enabling heartbeat sets next_heartbeat_at to interval from now" do
    freeze_time do
      @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
      assert_in_delta 15.minutes.from_now, @role.reload.next_heartbeat_at, 1.second
    end
  end

  test "disabling heartbeat clears next_heartbeat_at" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    assert @role.reload.next_heartbeat_at.present?

    @role.update!(heartbeat_enabled: false)
    assert_nil @role.reload.next_heartbeat_at
  end

  test "changing interval recomputes next_heartbeat_at" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    freeze_time do
      @role.update!(heartbeat_interval: 30)
      assert_in_delta 30.minutes.from_now, @role.reload.next_heartbeat_at, 1.second
    end
  end

  test "terminating role clears next_heartbeat_at" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    assert @role.reload.next_heartbeat_at.present?

    @role.update!(status: :terminated)
    assert_nil @role.reload.next_heartbeat_at
  end

  # --- scan_due_heartbeats ---

  test "scan_due_heartbeats enqueues a job for each due role" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_column(:next_heartbeat_at, 1.minute.ago)

    assert_enqueued_with(job: RoleHeartbeatJob, args: [ @role.id ]) do
      Role.scan_due_heartbeats
    end
  end

  test "scan_due_heartbeats advances next_heartbeat_at to act as claim" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_column(:next_heartbeat_at, 1.minute.ago)

    Role.scan_due_heartbeats

    @role.reload
    assert @role.next_heartbeat_at > Time.current
  end

  test "scan_due_heartbeats skips roles whose next_heartbeat_at is in the future" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_column(:next_heartbeat_at, 1.hour.from_now)

    assert_no_enqueued_jobs only: RoleHeartbeatJob do
      Role.scan_due_heartbeats
    end
  end

  test "scan_due_heartbeats skips disabled heartbeats" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_columns(heartbeat_enabled: false, next_heartbeat_at: 1.minute.ago)

    assert_no_enqueued_jobs only: RoleHeartbeatJob do
      Role.scan_due_heartbeats
    end
  end

  test "scan_due_heartbeats skips terminated roles" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_columns(status: Role.statuses[:terminated], next_heartbeat_at: 1.minute.ago)

    assert_no_enqueued_jobs only: RoleHeartbeatJob do
      Role.scan_due_heartbeats
    end
  end

  test "second scan after a claim does not re-enqueue" do
    @role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    @role.update_column(:next_heartbeat_at, 1.minute.ago)

    Role.scan_due_heartbeats
    clear_enqueued_jobs

    assert_no_enqueued_jobs only: RoleHeartbeatJob do
      Role.scan_due_heartbeats
    end
  end
end
