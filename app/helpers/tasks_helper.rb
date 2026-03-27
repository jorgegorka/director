module TasksHelper
  def task_status_badge(task)
    css_class = "status-badge status-badge--#{task.status}"
    tag.span(task.status.humanize, class: css_class)
  end

  def task_priority_badge(task)
    css_class = "priority-badge priority-badge--#{task.priority}"
    tag.span(task.priority.humanize, class: css_class)
  end

  def options_for_task_status
    Task.statuses.keys.map { |s| [ s.humanize, s ] }
  end

  def options_for_task_priority
    Task.priorities.keys.map { |p| [ p.humanize, p ] }
  end

  def options_for_assignee_select
    Current.company.agents.active.order(:name).map { |a| [ a.name, a.id ] }
  end

  # Human-readable description for any audit event action.
  # Handles all current and Plan-03 event types: created, assigned, status_changed, delegated, escalated.
  def audit_event_description(event)
    case event.action
    when "created"
      "Task created"
    when "assigned"
      "Assigned to #{event.metadata["assignee_name"]}"
    when "status_changed"
      "Status changed from #{event.metadata["from"]} to #{event.metadata["to"]}"
    when "delegated"
      desc = "Delegated from #{event.metadata["from_agent_name"]} to #{event.metadata["to_agent_name"]}"
      desc += " — #{event.metadata["reason"]}" if event.metadata["reason"].present?
      desc
    when "escalated"
      desc = "Escalated from #{event.metadata["from_agent_name"]} to #{event.metadata["to_agent_name"]}"
      desc += " — #{event.metadata["reason"]}" if event.metadata["reason"].present?
      desc
    else
      event.action.humanize
    end
  end
end
