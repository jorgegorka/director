module OrgChartsHelper
  def roles_tree_data(root_roles, roles_by_parent_id)
    root_roles.map { |role| role_node_data(role, roles_by_parent_id) }
  end

  def status_label_for(role)
    case role.status
    when "idle"             then "IDLE"
    when "running"          then "WORKING"
    when "paused"           then "PAUSED"
    when "error"            then "ERROR"
    when "terminated"       then "OFFLINE"
    when "pending_approval" then "AWAITING APPROVAL"
    end
  end

  private

  def role_node_data(role, roles_by_parent_id)
    children = (roles_by_parent_id[role.id] || []).sort_by(&:title)
    {
      id: role.id,
      title: role.title,
      description: role.description.to_s.truncate(80),
      url: role_path(role),
      status: role.status,
      parent_id: role.parent_id,
      adapter_type: role.adapter_type,
      working_directory: role.working_directory,
      role_category_id: role.role_category_id,
      children: children.map { |child| role_node_data(child, roles_by_parent_id) }
    }
  end
end
