module ApplicationHelper
  def polymorphic_actor_label(record, type_method: :actor_type, assoc: :actor)
    type = record.public_send(type_method)
    obj = record.public_send(assoc)
    case type
    when "User"  then obj&.email_address || "Unknown user"
    when "Role"  then obj&.title || "Unknown role"
    else "System"
    end
  end

  # Safe route generation for contexts where routing might not be fully established
  def safe_roles_path
    roles_path if Current.project && defined?(roles_path)
  rescue StandardError
    nil
  end
end
