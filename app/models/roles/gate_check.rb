module Roles
  class GateCheck
    attr_reader :role, :action_type, :context

    def initialize(role:, action_type:, context: {})
      @role = role
      @action_type = action_type
      @context = context
    end

    def self.check!(role:, action_type:, context: {})
      new(role: role, action_type: action_type, context: context).check!
    end

    # Returns true if action is allowed (no gate or gate disabled), false if blocked
    def check!
      return true unless role.gate_enabled?(action_type)
      return true if role.terminated?

      pause_for_approval!
      notify_gate_triggered!
      record_audit_event!("gate_blocked")
      false
    end

    private

    def pause_for_approval!
      role.update!(
        status: :pending_approval,
        pause_reason: "Approval required: #{action_type.humanize} gate is active",
        paused_at: Time.current
      )
    end

    def notify_gate_triggered!(action = "gate_pending_approval")
      role.company.admin_recipients.each do |user|
        Notification.create!(
          company: role.company,
          recipient: user,
          actor: role,
          notifiable: role,
          action: action,
          metadata: {
            role_title: role.title,
            role_id: role.id,
            action_type: action_type,
            context: context
          }
        )
      end
    end

    def record_audit_event!(audit_action)
      AuditEvent.create!(
        auditable: role,
        actor: role,
        action: audit_action,
        company: role.company,
        metadata: {
          action_type: action_type,
          role_title: role.title,
          context: context
        }
      )
    end
  end
end
