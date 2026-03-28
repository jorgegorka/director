class AgentRun < ApplicationRecord
  include Tenantable
  include Chronological

  belongs_to :agent
  belongs_to :task, optional: true

  enum :status, { queued: 0, running: 1, completed: 2, failed: 3, cancelled: 4 }

  validates :status, presence: true

  scope :for_agent, ->(agent) { where(agent: agent) }
  scope :active, -> { where(status: [ :queued, :running ]) }
  scope :terminal, -> { where(status: [ :completed, :failed, :cancelled ]) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }

  def mark_running!
    raise "Cannot transition to running from #{status}" unless queued?
    update!(status: :running, started_at: Time.current)
  end

  def mark_completed!(exit_code: nil, cost_cents: nil, claude_session_id: nil)
    update!(
      status: :completed,
      exit_code: exit_code,
      cost_cents: cost_cents,
      claude_session_id: claude_session_id || self.claude_session_id,
      completed_at: Time.current
    )
  end

  def mark_failed!(error_message:, exit_code: nil)
    update!(
      status: :failed,
      error_message: error_message,
      exit_code: exit_code,
      completed_at: Time.current
    )
  end

  def mark_cancelled!
    raise "Cannot cancel a #{status} run" if completed? || failed?
    update!(status: :cancelled, completed_at: Time.current)
  end

  def append_log!(text)
    return if text.blank?
    current = log_output || ""
    update!(log_output: current + text)
  end

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end

  def terminal?
    completed? || failed? || cancelled?
  end
end
