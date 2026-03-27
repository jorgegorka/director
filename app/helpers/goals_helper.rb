module GoalsHelper
  # Returns select options for parent goal dropdown.
  # Excludes the goal itself and its descendants (prevents cycles).
  # Indents titles by depth for visual hierarchy.
  def options_for_parent_goal_select(goal = nil)
    goals = Current.company.goals.roots.ordered
    build_goal_options(goals, goal, 0)
  end

  # Returns select options for goal dropdown on task form.
  # Flat list of all goals indented by depth.
  def options_for_goal_select
    goals = Current.company.goals.roots.ordered
    build_goal_options(goals, nil, 0)
  end

  # CSS class for progress bar color based on percentage
  def progress_bar_class(percentage)
    case percentage
    when 0 then "progress-bar--empty"
    when 1..49 then "progress-bar--low"
    when 50..89 then "progress-bar--mid"
    when 90..100 then "progress-bar--high"
    else "progress-bar--empty"
    end
  end

  private

  def build_goal_options(goals, exclude_goal, depth)
    options = []
    goals.each do |g|
      next if exclude_goal && (g.id == exclude_goal.id || exclude_goal.descendants.map(&:id).include?(g.id))
      prefix = "\u00A0\u00A0" * depth  # non-breaking spaces for indent
      options << [ "#{prefix}#{g.title}", g.id ]
      options.concat(build_goal_options(g.children.ordered, exclude_goal, depth + 1))
    end
    options
  end
end
