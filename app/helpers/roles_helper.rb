module RolesHelper
  def options_for_parent_select(role)
    # Get all roles in the current company except the role itself and its descendants
    excluded_ids = role.persisted? ? [ role.id ] + role.descendant_ids : []
    available_roles = Current.company.roles.where.not(id: excluded_ids).order(:title)
    available_roles.map { |r| [ r.title, r.id ] }
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
end
