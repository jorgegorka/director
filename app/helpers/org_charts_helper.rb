module OrgChartsHelper
  def roles_tree_data(root_roles)
    root_roles.map { |role| role_node_data(role) }
  end

  private

  def role_node_data(role)
    {
      id: role.id,
      title: role.title,
      description: role.description.to_s.truncate(80),
      url: role_path(role),
      agent_name: nil,
      children: role.children.order(:title).map { |child| role_node_data(child) }
    }
  end
end
