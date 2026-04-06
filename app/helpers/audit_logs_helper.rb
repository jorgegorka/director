module AuditLogsHelper
  def audit_action_badge(action)
    css_class = case action
    when *AuditEvent::GOVERNANCE_ACTIONS
                  "audit-badge--governance"
    when "created", "assigned"
                  "audit-badge--info"
    when "status_changed", "updated"
                  "audit-badge--change"
    when "destroyed"
                  "audit-badge--danger"
    else
                  "audit-badge--default"
    end
    tag.span(action.humanize, class: "audit-badge #{css_class}")
  end

  def audit_actor_display(event)
    polymorphic_actor_label(event)
  end

  def audit_auditable_display(event)
    case event.auditable_type
    when "Task"
      link_to_if(event.auditable, event.auditable&.title || "Deleted task", event.auditable)
    when "Role"
      link_to_if(event.auditable, event.auditable&.title || "Deleted role", event.auditable)
    when "Goal"
      link_to_if(event.auditable, event.auditable&.title || "Deleted goal", event.auditable)
    when "Project"
      label = event.auditable&.name || "Project"
      if event.action == "destroyed" && event.metadata["destroyed_type"].present?
        "#{event.metadata['destroyed_type']}: #{event.metadata['title'] || event.metadata['destroyed_id']}"
      else
        label
      end
    else
      "#{event.auditable_type} ##{event.auditable_id}"
    end
  end

  def audit_metadata_display(metadata)
    return "" if metadata.blank?
    metadata.map { |k, v| "#{k.humanize}: #{v}" }.join(", ")
  end
end
