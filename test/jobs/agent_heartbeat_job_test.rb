require "test_helper"

class RoleHeartbeatJobTest < ActiveSupport::TestCase
  setup do
    @role = roles(:developer)
    @role.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
  end

  test "creates heartbeat event for scheduled role" do
    assert_difference -> { HeartbeatEvent.count }, 1 do
      RoleHeartbeatJob.new.perform(@role.id)
    end
    event = HeartbeatEvent.last
    assert event.scheduled?
    assert_equal @role, event.role
  end

  test "skips role that is not heartbeat_scheduled" do
    @role.update_columns(heartbeat_enabled: false)
    assert_no_difference -> { HeartbeatEvent.count } do
      RoleHeartbeatJob.new.perform(@role.id)
    end
  end

  test "skips terminated role" do
    @role.update_columns(status: Role.statuses[:terminated])
    assert_no_difference -> { HeartbeatEvent.count } do
      RoleHeartbeatJob.new.perform(@role.id)
    end
  end

  test "skips non-existent role" do
    assert_no_difference -> { HeartbeatEvent.count } do
      RoleHeartbeatJob.new.perform(999999)
    end
  end
end
