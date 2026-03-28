module ApplicationHelper
  def options_for_agent_select
    Current.company.agents.active.order(:name).map { |a| [ a.name, a.id ] }
  end

  def polymorphic_actor_label(record, type_method: :actor_type, assoc: :actor)
    type = record.public_send(type_method)
    obj = record.public_send(assoc)
    case type
    when "User"  then obj&.email_address || "Unknown user"
    when "Agent" then obj&.name || "Unknown agent"
    else "System"
    end
  end
end
