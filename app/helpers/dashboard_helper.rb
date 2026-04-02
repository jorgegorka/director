module DashboardHelper
  def stat_card_trend_class(value)
    value.to_i > 0 ? "stat-card--positive" : "stat-card--zero"
  end

  def tab_link_class(tab_name, current_tab)
    tab_name == current_tab ? "dashboard-tab--active" : nil
  end
end
