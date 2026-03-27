module AgentsHelper
  def agent_status_badge(agent)
    css_class = "status-badge status-badge--#{agent.status}"
    tag.span(agent.status.humanize, class: css_class)
  end

  def adapter_type_label(agent)
    AdapterRegistry.for(agent.adapter_type).display_name
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
      "status_change" => "Pause before changing task or agent status",
      "escalation" => "Pause before escalating tasks to managers"
    }
    descriptions[action_type] || action_type.humanize
  end

  def gate_status_indicator(agent)
    if agent.has_any_gates?
      count = agent.approval_gates.enabled.count
      tag.span("#{count} gate#{"s" if count != 1} active", class: "gate-indicator gate-indicator--active")
    else
      tag.span("No gates", class: "gate-indicator gate-indicator--none")
    end
  end
end
