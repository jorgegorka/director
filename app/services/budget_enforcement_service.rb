class BudgetEnforcementService
  include BudgetHelper

  PAUSE_REASON_PREFIX = "Budget exhausted"

  attr_reader :agent

  def initialize(agent)
    @agent = agent
  end

  def self.check!(agent)
    new(agent).check!
  end

  def check!
    return unless agent.budget_configured?
    return if agent.terminated?

    if agent.budget_exhausted?
      pause_agent!
      notify_budget_exhausted!
    elsif agent.budget_alert_threshold?
      notify_budget_alert!
    end
  end

  private

  def pause_agent!
    return if agent.paused? && agent.pause_reason&.start_with?(PAUSE_REASON_PREFIX)

    agent.update!(
      status: :paused,
      pause_reason: "#{PAUSE_REASON_PREFIX}: spent #{format_cents_as_dollars(agent.monthly_spend_cents)} of #{format_cents_as_dollars(agent.budget_cents)} monthly budget",
      paused_at: Time.current
    )
  end

  def notify_budget_exhausted!
    notify!("budget_exhausted")
  end

  def notify_budget_alert!
    notify!("budget_alert", percentage: agent.budget_utilization)
  end

  def notify!(action, extra_metadata = {})
    return if already_notified?(action)

    metadata = {
      agent_name: agent.name,
      agent_id: agent.id,
      budget_cents: agent.budget_cents,
      spent_cents: agent.monthly_spend_cents,
      period_start: agent.current_budget_period_start.to_s
    }.merge(extra_metadata)

    agent.company.admin_recipients.each do |user|
      Notification.create!(
        company: agent.company,
        recipient: user,
        actor: agent,
        notifiable: agent,
        action: action,
        metadata: metadata
      )
    end
  end

  def already_notified?(action)
    Notification.where(
      notifiable: agent,
      action: action
    ).where(
      "created_at >= ?", agent.current_budget_period_start.beginning_of_day
    ).exists?
  end
end
