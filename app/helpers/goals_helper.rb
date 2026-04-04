module GoalsHelper
  def options_for_goal_select
    Current.company.goals.ordered.pluck(:title, :id)
  end

  def eval_pass_rate(pass_count, total)
    return 0 if total.zero?
    (pass_count.to_f / total * 100).round
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
end
