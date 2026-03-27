module GoalsHelper
  def options_for_goal_select(exclude: nil)
    goals = Current.company.goals.roots.ordered
    excluded_ids = exclude ? Set.new([ exclude.id ] + exclude.descendants.map(&:id)) : Set.new
    build_goal_options(goals, excluded_ids, 0)
  end

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

  def build_goal_options(goals, excluded_ids, depth)
    options = []
    goals.each do |g|
      next if excluded_ids.include?(g.id)
      prefix = "\u00A0\u00A0" * depth
      options << [ "#{prefix}#{g.title}", g.id ]
      options.concat(build_goal_options(g.children.ordered, excluded_ids, depth + 1))
    end
    options
  end
end
