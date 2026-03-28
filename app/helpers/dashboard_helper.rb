module DashboardHelper
  def stat_card_trend_class(value)
    value.to_i > 0 ? "stat-card--positive" : "stat-card--zero"
  end

  def budget_summary_percentage(spend, budget)
    return 0.0 unless budget.to_i > 0
    (spend.to_f / budget * 100).round(1)
  end

  def tab_link_class(tab_name, current_tab)
    tab_name == current_tab ? "dashboard-tab--active" : nil
  end
end
