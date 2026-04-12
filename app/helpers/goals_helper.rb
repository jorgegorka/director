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
end
