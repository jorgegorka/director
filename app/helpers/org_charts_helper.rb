module OrgChartsHelper
  def roles_tree_data(root_roles, roles_by_parent_id)
    root_roles.map { |role| role_node_data(role, roles_by_parent_id) }
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
      children: children.map { |child| role_node_data(child, roles_by_parent_id) }
    }
  end
end
