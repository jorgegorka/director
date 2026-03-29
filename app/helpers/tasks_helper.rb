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

  def delegation_targets_for(task)
    return [] unless task.assignee.present?
    task.assignee.subordinate_roles.order(:title).map { |r| [ r.title, r.id ] }
  end

  def can_escalate?(task)
    task.assignee&.manager_role.present?
  end

  def escalation_target_name(task)
    task.assignee&.manager_role&.title
  end

  def audit_event_description(event)
    meta = event.metadata
    case event.action
    when "created"
      "Task created"
    when "assigned"
      "Assigned to #{meta["assignee_name"]}"
    when "status_changed"
      "Status changed from #{meta["from"]} to #{meta["to"]}"
    when "delegated", "escalated"
      desc = "#{event.action.humanize} from #{meta["from_role_name"] || meta["from_agent_name"]} to #{meta["to_role_name"] || meta["to_agent_name"]}"
      desc += " — #{meta["reason"]}" if meta["reason"].present?
      desc
    else
      event.action.humanize
    end
  end
end
