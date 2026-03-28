module AgentHooksHelper
  def lifecycle_event_label(event)
    labels = {
      "after_task_start" => "After Task Starts",
      "after_task_complete" => "After Task Completes"
    }
    labels[event] || event.humanize
  end

  def lifecycle_event_options
    AgentHook::LIFECYCLE_EVENTS.map { |e| [ lifecycle_event_label(e), e ] }
  end

  def action_type_label(action_type)
    labels = {
      "trigger_agent" => "Trigger Agent",
      "webhook" => "Webhook"
    }
    labels[action_type] || action_type.humanize
  end

  def action_type_options
    AgentHook.action_types.keys.map { |t| [ action_type_label(t), t ] }
  end

  def hook_status_badge(hook)
    if hook.enabled?
      tag.span("Enabled", class: "hook-status-badge hook-status-badge--enabled")
    else
      tag.span("Disabled", class: "hook-status-badge hook-status-badge--disabled")
    end
  end

  def hook_execution_status_badge(execution)
    css_class = "execution-status-badge execution-status-badge--#{execution.status}"
    tag.span(execution.status.humanize, class: css_class)
  end
end
