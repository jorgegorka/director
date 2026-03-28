class HookExecution < ApplicationRecord
  belongs_to :agent_hook
  belongs_to :task
  belongs_to :company

  enum :status, { queued: 0, running: 1, completed: 2, failed: 3 }

  validates :status, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }
  scope :for_task, ->(task) { where(task: task) }

  def mark_running!
    update!(
      status: :running,
      started_at: Time.current
    )
  end

  def mark_completed!(output: {})
    update!(
      status: :completed,
      output_payload: output,
      completed_at: Time.current
    )
  end

  def mark_failed!(error_message:)
    update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
  end

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end
end
