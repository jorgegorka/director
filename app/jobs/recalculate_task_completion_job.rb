class RecalculateTaskCompletionJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task

    task.recalculate_completion!
    RecalculateTaskCompletionJob.perform_later(task.parent_task_id) if task.parent_task_id
  end
end
