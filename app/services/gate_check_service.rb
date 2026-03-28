class GateCheckService
  attr_reader :agent, :action_type, :context

  def initialize(agent:, action_type:, context: {})
    @agent = agent
    @action_type = action_type
    @context = context
  end

  def self.check!(agent:, action_type:, context: {})
    new(agent: agent, action_type: action_type, context: context).check!
  end

  # Returns true if action is allowed (no gate or gate disabled), false if blocked
  def check!
    return true unless agent.gate_enabled?(action_type)
    return true if agent.terminated?

    pause_for_approval!
    notify_gate_triggered!
    record_audit_event!("gate_blocked")
    false
  end

  private

  def pause_for_approval!
    agent.update!(
      status: :pending_approval,
      pause_reason: "Approval required: #{action_type.humanize} gate is active",
      paused_at: Time.current
    )
  end

  def notify_gate_triggered!(action = "gate_pending_approval")
    agent.company.admin_recipients.each do |user|
      Notification.create!(
        company: agent.company,
        recipient: user,
        actor: agent,
        notifiable: agent,
        action: action,
        metadata: {
          agent_name: agent.name,
          agent_id: agent.id,
          action_type: action_type,
          context: context
        }
      )
    end
  end

  def record_audit_event!(audit_action)
    AuditEvent.create!(
      auditable: agent,
      actor: agent,
      action: audit_action,
      company: agent.company,
      metadata: {
        action_type: action_type,
        agent_name: agent.name,
        context: context
      }
    )
  end
end
