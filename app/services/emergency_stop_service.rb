class EmergencyStopService
  PAUSE_REASON = "Emergency stop: all agents paused by administrator"

  attr_reader :company, :user

  def initialize(company:, user:)
    @company = company
    @user = user
  end

  def self.call!(company:, user:)
    new(company: company, user: user).call!
  end

  def call!
    roles_to_pause = company.roles.active.where.not(status: [ :paused, :terminated ])
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
      auditable: company,
      actor: user,
      action: "emergency_stop",
      company: company,
      metadata: {
        roles_paused: paused_count,
        triggered_by: user.email_address
      }
    )
  end

  def notify_emergency_stop!(paused_count)
    company.admin_recipients.each do |recipient_user|
      Notification.create!(
        company: company,
        recipient: recipient_user,
        actor: user,
        notifiable: company,
        action: "emergency_stop",
        metadata: {
          roles_paused: paused_count,
          triggered_by: user.email_address
        }
      )
    end
  end
end
