class ExecuteHookJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(hook_execution_id)
    execution = HookExecution.find_by(id: hook_execution_id)
    return unless execution
    return if execution.completed? || execution.failed?

    ExecuteHookService.call(execution)
  end
end
