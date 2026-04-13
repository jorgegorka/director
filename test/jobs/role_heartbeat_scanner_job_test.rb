require "test_helper"

class RoleHeartbeatScannerJobTest < ActiveJob::TestCase
  test "delegates to Role.scan_due_heartbeats" do
    role = roles(:developer)
    role.update!(heartbeat_enabled: true, heartbeat_interval: 15)
    role.update_column(:next_heartbeat_at, 1.minute.ago)

    assert_enqueued_with(job: RoleHeartbeatJob, args: [ role.id ]) do
      RoleHeartbeatScannerJob.perform_now
    end
  end
end
