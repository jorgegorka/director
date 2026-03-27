module HeartbeatsHelper
  def heartbeat_trigger_badge(event)
    label = case event.trigger_type
    when "scheduled" then "Scheduled"
    when "task_assigned" then "Task Assigned"
    when "mention" then "Mentioned"
    else event.trigger_type.humanize
    end

    css_class = "heartbeat-badge heartbeat-badge--#{event.trigger_type}"
    tag.span(label, class: css_class)
  end

  def heartbeat_status_indicator(event)
    label = event.status.humanize
    css_class = "heartbeat-status heartbeat-status--#{event.status}"
    tag.span(label, class: css_class)
  end

  def heartbeat_schedule_label(agent)
    return "No schedule" unless agent.heartbeat_scheduled?

    interval = agent.heartbeat_interval
    if interval < 60
      "Every #{interval} minutes"
    elsif interval == 60
      "Every hour"
    elsif interval % 60 == 0
      "Every #{interval / 60} hours"
    else
      "Every #{interval} minutes"
    end
  end
end
