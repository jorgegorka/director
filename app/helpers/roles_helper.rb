module RolesHelper
  def options_for_role_select(exclude: nil, scope: :active)
    base = Current.project.roles
    base = base.send(scope) unless scope == :all
    roles = base.roots.order(:title)
    excluded_ids = exclude ? Set.new([ exclude.id ] + exclude.descendant_ids) : Set.new
    build_role_options(roles, excluded_ids, 0, scope)
  end

  def options_for_parent_select(role)
    options_for_role_select(exclude: role, scope: :all)
  end

  def role_status_badge(role)
    css_class = "status-badge status-badge--#{role.status}"
    tag.span(role.status.humanize, class: css_class)
  end

  def adapter_type_label(role)
    return "Vacant" unless role.adapter_type.present?
    AdapterRegistry.for(role.adapter_type).display_name
  end

  def adapter_type_options
    AdapterRegistry.adapter_types.map do |type|
      adapter_class = AdapterRegistry.for(type)
      [ adapter_class.display_name, type ]
    end
  end

  def gate_description(action_type)
    descriptions = {
      "task_creation" => "Pause before creating new tasks",
      "task_delegation" => "Pause before delegating tasks to subordinates",
      "budget_spend" => "Pause before recording costs against budget",
      "status_change" => "Pause before changing task or role status",
      "escalation" => "Pause before escalating tasks to managers"
    }
    descriptions[action_type] || action_type.humanize
  end

  def gate_status_indicator(role)
    if role.has_any_gates?
      count = role.approval_gates.enabled.count
      tag.span("#{count} gate#{"s" if count != 1} active", class: "gate-indicator gate-indicator--active")
    else
      tag.span("No gates", class: "gate-indicator gate-indicator--none")
    end
  end

  private

  def build_role_options(roles, excluded_ids, depth, scope)
    options = []
    roles.each do |r|
      next if excluded_ids.include?(r.id)
      prefix = "\u00A0\u00A0" * depth
      options << [ "#{prefix}#{r.title}", r.id ]
      children = r.children.order(:title)
      children = children.send(scope) unless scope == :all
      options.concat(build_role_options(children, excluded_ids, depth + 1, scope))
    end
    options
  end
end
