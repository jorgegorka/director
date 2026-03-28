class ProcessValidationResultJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task
    return unless task.completed?
    return unless task.parent_task_id.present?

    ProcessValidationResultService.call(task)
  end
end
