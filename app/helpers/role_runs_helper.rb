module RoleRunsHelper
  def role_run_status_badge(role_run)
    css_class = "status-badge status-badge--#{role_run.status}"
    tag.span(role_run.status.humanize, class: css_class)
  end

  def role_run_duration(role_run)
    seconds = role_run.duration_seconds
    return "---" unless seconds
    if seconds < 60
      "#{seconds}s"
    else
      minutes = (seconds / 60).floor
      remaining = (seconds % 60).round
      "#{minutes}m #{remaining}s"
    end
  end
end
