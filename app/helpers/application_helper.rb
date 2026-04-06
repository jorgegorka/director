module ApplicationHelper
  def options_for_role_select
    Current.project.roles.active.order(:title).map { |r| [ r.title, r.id ] }
  end

  def polymorphic_actor_label(record, type_method: :actor_type, assoc: :actor)
    type = record.public_send(type_method)
    obj = record.public_send(assoc)
    case type
    when "User"  then obj&.email_address || "Unknown user"
    when "Role"  then obj&.title || "Unknown role"
    else "System"
    end
  end
end
