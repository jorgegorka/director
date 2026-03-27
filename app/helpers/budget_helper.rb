module BudgetHelper
  def format_cents_as_dollars(cents)
    return "---" if cents.nil?
    "$#{'%.2f' % (cents / 100.0)}"
  end

  def budget_bar_class(utilization)
    case utilization
    when 0 then "budget-bar--empty"
    when 0.1..49.9 then "budget-bar--low"
    when 50.0..79.9 then "budget-bar--mid"
    when 80.0..99.9 then "budget-bar--high"
    else "budget-bar--exhausted"  # 100+
    end
  end

  def budget_status_text(agent)
    return "No budget set" unless agent.budget_configured?
    if agent.budget_exhausted?
      "Budget exhausted"
    elsif agent.budget_alert_threshold?
      "Approaching limit (#{agent.budget_utilization}%)"
    else
      "#{agent.budget_utilization}% used"
    end
  end
end
