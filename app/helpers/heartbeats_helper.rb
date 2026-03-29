module HeartbeatsHelper
  TRIGGER_LABELS = {
    "scheduled" => "Scheduled",
    "task_assigned" => "Task Assigned",
    "mention" => "Mentioned"
  }.freeze

  def heartbeat_trigger_badge(event)
    label = TRIGGER_LABELS.fetch(event.trigger_type, event.trigger_type.humanize)
    tag.span(label, class: "heartbeat-badge heartbeat-badge--#{event.trigger_type}")
  end

  def heartbeat_status_indicator(event)
    tag.span(event.status.humanize, class: "heartbeat-status heartbeat-status--#{event.status}")
  end

  def heartbeat_schedule_label(role)
    return "No schedule" unless role.heartbeat_scheduled?

    interval = role.heartbeat_interval
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
