class BudgetEnforcementService
  include BudgetHelper

  PAUSE_REASON_PREFIX = "Budget exhausted"

  attr_reader :role

  def initialize(role)
    @role = role
  end

  def self.check!(role)
    new(role).check!
  end

  def check!
    return unless role.budget_configured?
    return if role.terminated?

    if role.budget_exhausted?
      pause_role!
      notify_budget_exhausted!
    elsif role.budget_alert_threshold?
      notify_budget_alert!
    end
  end

  private

  def pause_role!
    return if role.paused? && role.pause_reason&.start_with?(PAUSE_REASON_PREFIX)

    role.update!(
      status: :paused,
      pause_reason: "#{PAUSE_REASON_PREFIX}: spent #{format_cents_as_dollars(role.monthly_spend_cents)} of #{format_cents_as_dollars(role.budget_cents)} monthly budget",
      paused_at: Time.current
    )
  end

  def notify_budget_exhausted!
    notify!("budget_exhausted")
  end

  def notify_budget_alert!
    notify!("budget_alert", percentage: role.budget_utilization)
  end

  def notify!(action, extra_metadata = {})
    return if already_notified?(action)

    metadata = {
      role_title: role.title,
      role_id: role.id,
      budget_cents: role.budget_cents,
      spent_cents: role.monthly_spend_cents,
      period_start: role.current_budget_period_start.to_s
    }.merge(extra_metadata)

    role.company.admin_recipients.each do |user|
      Notification.create!(
        company: role.company,
        recipient: user,
        actor: role,
        notifiable: role,
        action: action,
        metadata: metadata
      )
    end
  end

  def already_notified?(action)
    Notification.where(
      notifiable: role,
      action: action
    ).where(
      "created_at >= ?", role.current_budget_period_start.beginning_of_day
    ).exists?
  end
end
