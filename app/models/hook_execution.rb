class HookExecution < ApplicationRecord
  include Tenantable
  include Chronological
  include Runnable

  belongs_to :role_hook
  belongs_to :task

  enum :status, { queued: 0, running: 1, completed: 2, failed: 3 }

  scope :for_task, ->(task) { where(task: task) }

  # Hooks allow retry from failed state
  def mark_running!
    return if running?
    raise "Cannot transition to running from #{status}" unless queued? || failed?
    update!(status: :running, started_at: Time.current)
  end

  def mark_completed!(output: {})
    update!(
      status: :completed,
      output_payload: output,
      completed_at: Time.current
    )
  end
end
