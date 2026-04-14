module GoalsHelper
  def progress_bar_class(percentage)
    case percentage
    when 0 then "progress-bar--empty"
    when 1..49 then "progress-bar--low"
    when 50..89 then "progress-bar--mid"
    when 90..100 then "progress-bar--high"
    else "progress-bar--empty"
    end
  end

  GOAL_PILL_ICONS = {
    recurring: '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10a6 6 0 0110-4.3L16 7"/><path d="M16 4v3h-3"/><path d="M16 10a6 6 0 01-10 4.3L4 13"/><path d="M4 16v-3h3"/></svg>'
  }.freeze
  private_constant :GOAL_PILL_ICONS

  def goal_pill_icon(name)
    svg = GOAL_PILL_ICONS.fetch(name) { raise ArgumentError, "unknown goal pill icon: #{name.inspect}" }
    svg.html_safe
  end
end
