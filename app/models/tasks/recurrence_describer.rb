module Tasks
  class RecurrenceDescriber
    def initialize(task)
      @task = task
    end

    def to_sentence
      return nil unless @task.recurring?

      "Repeats #{interval_phrase}#{anchor_phrase} at #{time_phrase} (#{@task.recurrence_timezone})"
    end

    private

    def interval_phrase
      n = @task.recurrence_interval
      unit = @task.recurrence_unit
      "every #{n == 1 ? unit : "#{n} #{unit.pluralize}"}"
    end

    def anchor_phrase
      anchor = @task.recurrence_anchor_at.in_time_zone(@task.recurrence_timezone)
      case @task.recurrence_unit
      when "week" then " on #{Date::DAYNAMES[anchor.wday]}"
      when "month" then " on day #{anchor.day}"
      else ""
      end
    end

    def time_phrase
      anchor = @task.recurrence_anchor_at.in_time_zone(@task.recurrence_timezone)
      format("%02d:%02d", anchor.hour, anchor.min)
    end
  end
end
