class RoleHeartbeatScannerJob < ApplicationJob
  queue_as :default

  def perform
    Role.scan_due_heartbeats
  end
end
