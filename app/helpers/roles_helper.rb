module RolesHelper
  def options_for_parent_select(role)
    # Get all roles in the current company except the role itself and its descendants
    excluded_ids = role.persisted? ? [ role.id ] + role.descendants.map(&:id) : []
    available_roles = Current.company.roles.where.not(id: excluded_ids).order(:title)
    available_roles.map { |r| [ r.title, r.id ] }
  end

  def options_for_agent_select
    Current.company.agents.active.order(:name).map { |a| [ a.name, a.id ] }
  end
end
