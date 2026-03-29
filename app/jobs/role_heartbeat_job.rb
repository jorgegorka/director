class RoleHeartbeatJob < ApplicationJob
  queue_as :default

  def perform(role_id)
    role = Role.find_by(id: role_id)
    return unless role
    return unless role.heartbeat_scheduled?
    return if role.terminated?

    WakeRoleService.call(
      role: role,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )
  end
end
