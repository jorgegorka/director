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

  def options_for_parent_task_select(task)
    scope = Current.project.tasks
    if task.persisted?
      excluded = [ task.id ] + task.descendant_ids
      scope = scope.where.not(id: excluded)
    end
    scope.order(:title).pluck(:title, :id)
  end

  TASK_PILL_ICONS = {
    assignee:    '<svg viewBox="0 0 20 20" fill="currentColor"><circle cx="10" cy="7" r="3.25"/><path d="M3.5 17a6.5 6.5 0 0113 0z"/></svg>',
    creator:     '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M3 15l1.4-8 3.6 2.6L10 4l2 5.6L15.6 7 17 15H3zm0 1.5h14V18H3z"/></svg>',
    priority:    '<svg viewBox="0 0 20 20" fill="currentColor"><rect x="3" y="11" width="3" height="6" rx="0.5"/><rect x="8.5" y="7" width="3" height="10" rx="0.5"/><rect x="14" y="3" width="3" height="14" rx="0.5"/></svg>',
    parent_task: '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h10M8 10h7M8 16h7"/><path d="M5 4v12"/></svg>',
    due:         '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="14" height="12" rx="1.5"/><path d="M3 9h14M7 3v4M13 3v4"/></svg>'
  }.freeze
  private_constant :TASK_PILL_ICONS

  def task_pill_icon(name)
    svg = TASK_PILL_ICONS.fetch(name) { raise ArgumentError, "unknown task pill icon: #{name.inspect}" }
    svg.html_safe
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
