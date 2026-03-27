module NotificationsHelper
  def notification_icon(notification)
    case notification.action
    when "budget_alert" then "warning"
    when "budget_exhausted" then "error"
    else "info"
    end
  end

  def notification_message(notification)
    meta = notification.metadata
    case notification.action
    when "budget_alert"
      "#{meta['agent_name']} has used #{meta['percentage']}% of its monthly budget (#{format_cents_as_dollars(meta['spent_cents'])} of #{format_cents_as_dollars(meta['budget_cents'])})"
    when "budget_exhausted"
      "#{meta['agent_name']} has been paused — monthly budget exhausted (#{format_cents_as_dollars(meta['spent_cents'])} spent)"
    else
      notification.action.humanize
    end
  end

  def notification_link(notification)
    case notification.notifiable_type
    when "Agent"
      agent_path(notification.notifiable_id)
    else
      "#"
    end
  end
end
