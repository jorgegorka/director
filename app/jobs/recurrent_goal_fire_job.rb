class RecurrentGoalFireJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find_by(id: task_id)
    task&.fire_recurrence_now
  end
end
