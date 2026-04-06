module Roles
  class EmergencyStop
    PAUSE_REASON = "Emergency stop: all roles paused by administrator"

    attr_reader :project, :user

    def initialize(project:, user:)
      @project = project
      @user = user
    end

    def self.call!(project:, user:)
      new(project: project, user: user).call!
    end

    def call!
      roles_to_pause = project.roles.active.agent_configured.where.not(status: [ :paused, :terminated ])
      paused_count = 0

      roles_to_pause.find_each do |role|
        role.update!(
          status: :paused,
          pause_reason: PAUSE_REASON,
          paused_at: Time.current
        )
        paused_count += 1
      end

      record_audit_event!(paused_count)
      notify_emergency_stop!(paused_count)
      paused_count
    end

    private

    def record_audit_event!(paused_count)
      AuditEvent.create!(
        auditable: project,
        actor: user,
        action: "emergency_stop",
        project: project,
        metadata: {
          roles_paused: paused_count,
          triggered_by: user.email_address
        }
      )
    end

    def notify_emergency_stop!(paused_count)
      project.admin_recipients.each do |recipient_user|
        Notification.create!(
          project: project,
          recipient: recipient_user,
          actor: user,
          notifiable: project,
          action: "emergency_stop",
          metadata: {
            roles_paused: paused_count,
            triggered_by: user.email_address
          }
        )
      end
    end
  end
end
