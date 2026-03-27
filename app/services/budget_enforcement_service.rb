class BudgetEnforcementService
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
    return if agent.paused? && agent.pause_reason&.include?("Budget exhausted")

    agent.update!(
      status: :paused,
      pause_reason: "Budget exhausted: spent #{format_cents(agent.monthly_spend_cents)} of #{format_cents(agent.budget_cents)} monthly budget",
      paused_at: Time.current
    )
  end

  def notify_budget_exhausted!
    return if already_notified?("budget_exhausted")

    company_recipients.each do |user|
      Notification.create!(
        company: agent.company,
        recipient: user,
        actor: agent,
        notifiable: agent,
        action: "budget_exhausted",
        metadata: {
          agent_name: agent.name,
          agent_id: agent.id,
          budget_cents: agent.budget_cents,
          spent_cents: agent.monthly_spend_cents,
          period_start: agent.current_budget_period_start.to_s
        }
      )
    end
  end

  def notify_budget_alert!
    return if already_notified?("budget_alert")

    company_recipients.each do |user|
      Notification.create!(
        company: agent.company,
        recipient: user,
        actor: agent,
        notifiable: agent,
        action: "budget_alert",
        metadata: {
          agent_name: agent.name,
          agent_id: agent.id,
          percentage: agent.budget_utilization,
          budget_cents: agent.budget_cents,
          spent_cents: agent.monthly_spend_cents,
          period_start: agent.current_budget_period_start.to_s
        }
      )
    end
  end

  def already_notified?(action)
    # Dedup: only one notification per action per agent per budget period
    Notification.where(
      notifiable: agent,
      action: action
    ).where(
      "created_at >= ?", agent.current_budget_period_start.beginning_of_day
    ).exists?
  end

  def company_recipients
    # Notify all owners and admins of the company
    agent.company.memberships
      .where(role: [ :owner, :admin ])
      .includes(:user)
      .map(&:user)
  end

  def format_cents(cents)
    "$#{'%.2f' % (cents / 100.0)}"
  end
end
