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
end
