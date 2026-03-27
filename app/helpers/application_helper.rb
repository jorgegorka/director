module ApplicationHelper
  def options_for_agent_select
    Current.company.agents.active.order(:name).map { |a| [ a.name, a.id ] }
  end
end
