module AgentRunsHelper
  def agent_run_status_badge(agent_run)
    css_class = "status-badge status-badge--#{agent_run.status}"
    tag.span(agent_run.status.humanize, class: css_class)
  end

  def agent_run_duration(agent_run)
    seconds = agent_run.duration_seconds
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
