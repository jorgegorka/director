module NotificationsHelper
  def notification_icon(notification)
    case notification.action
    when "budget_alert" then "warning"
    when "budget_exhausted" then "error"
    when "gate_pending_approval" then "warning"
    when "gate_approval" then "success"
    when "gate_rejection" then "error"
    when "emergency_stop" then "error"
    else "info"
    end
  end

  def notification_message(notification)
    meta = notification.metadata
    case notification.action
    when "budget_alert"
      "#{meta['role_name'] || meta['agent_name']} has used #{meta['percentage']}% of its monthly budget (#{format_cents_as_dollars(meta['spent_cents'])} of #{format_cents_as_dollars(meta['budget_cents'])})"
    when "budget_exhausted"
      "#{meta['role_name'] || meta['agent_name']} has been paused — monthly budget exhausted (#{format_cents_as_dollars(meta['spent_cents'])} spent)"
    when "gate_pending_approval"
      "#{meta['role_name'] || meta['agent_name']} is waiting for approval: #{meta['action_type']&.humanize} gate triggered"
    when "gate_approval"
      "#{meta['role_name'] || meta['agent_name']} has been approved and resumed"
    when "gate_rejection"
      "#{meta['role_name'] || meta['agent_name']} approval was rejected"
    when "emergency_stop"
      "Emergency stop activated by #{meta['triggered_by']} — #{meta['roles_paused'] || meta['agents_paused']} role(s) paused"
    else
      notification.action.humanize
    end
  end

  def notification_link(notification)
    case notification.notifiable_type
    when "Role"
      role_path(notification.notifiable_id)
    when "Company"
      roles_path
    else
      "#"
    end
  end
end
