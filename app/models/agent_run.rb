class AgentRun < ApplicationRecord
  include Tenantable
  include Chronological
  include Runnable

  TERMINAL_STATUSES = %w[completed failed cancelled].freeze
  BROADCAST_MIN_INTERVAL = 0.1 # seconds (100ms) -- STREAM-05

  # Class-level tracking for broadcast timestamps per run.
  # Thread-safe via the GIL for single-process Puma; good enough for SQLite deployment.
  @@last_broadcast_at = {} # rubocop:disable Style/ClassVars

  belongs_to :agent
  belongs_to :task, optional: true

  enum :status, { queued: 0, running: 1, completed: 2, failed: 3, cancelled: 4 }

  validates :trigger_type, inclusion: { in: HeartbeatEvent.trigger_types.keys }, allow_nil: true

  scope :for_agent, ->(agent) { where(agent: agent) }
  scope :active, -> { where(status: [ :queued, :running ]) }
  scope :terminal, -> { where(status: TERMINAL_STATUSES) }

  after_commit :broadcast_flush!, if: :terminal_status_reached?

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
    update!(status: :failed, error_message: error_message, exit_code: exit_code, completed_at: Time.current)
  end

  def mark_cancelled!
    raise "Cannot cancel a #{status} run" if completed? || failed?
    update!(status: :cancelled, completed_at: Time.current)
  end

  # SQL-level concat avoids read-modify-write races.
  # Does NOT update the in-memory attribute; call reload if you need the value.
  def append_log!(text)
    return if text.blank?
    self.class.where(id: id).update_all(
      [ "log_output = COALESCE(log_output, '') || ?", text ]
    )
  end

  # Appends a line to log_output AND broadcasts it to subscribed browsers.
  # Called from adapter poll loops instead of append_log! directly.
  # Batching: only broadcasts if at least BROADCAST_MIN_INTERVAL has elapsed (STREAM-05).
  # Every line is still persisted via append_log! regardless of batching (no data loss).
  def broadcast_line!(text)
    return if text.blank?
    append_log!(text)

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    last = @@last_broadcast_at[id] || 0

    if (now - last) >= BROADCAST_MIN_INTERVAL
      @@last_broadcast_at[id] = now
      Turbo::StreamsChannel.broadcast_append_to(
        "agent_run_#{id}",
        target: "agent-run-output",
        partial: "agent_runs/log_line",
        locals: { text: text }
      )
    end
  end

  # Cleans up broadcast tracking state and removes the live indicator from the UI.
  # Called via after_commit callback when a run reaches a terminal state.
  def broadcast_flush!
    @@last_broadcast_at.delete(id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "agent_run_#{id}",
      target: "agent-run-live-indicator",
      html: ""
    )
  end

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  private

  def terminal_status_reached?
    saved_change_to_status? && terminal?
  end
end
