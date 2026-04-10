class RoleRun < ApplicationRecord
  include Tenantable
  include Chronological
  include Runnable
  include Triggerable

  TERMINAL_STATUSES = %w[completed failed cancelled].freeze
  BROADCAST_MIN_INTERVAL = 0.1 # seconds (100ms) -- STREAM-05

  # Class-level tracking for broadcast timestamps per run.
  # Thread-safe via the GIL for single-process Puma; good enough for SQLite deployment.
  @@last_broadcast_at = {} # rubocop:disable Style/ClassVars

  belongs_to :role
  belongs_to :task, optional: true

  has_many :sub_agent_invocations, dependent: :destroy

  enum :status, { queued: 0, running: 1, completed: 2, failed: 3, cancelled: 4, throttled: 5 }

  validates :trigger_type, inclusion: { in: HeartbeatEvent.trigger_types.keys }, allow_nil: true

  scope :for_role, ->(role) { where(role: role) }
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
    release_role_and_dispatch!
  end

  def mark_failed!(error_message:, exit_code: nil)
    update!(status: :failed, error_message: error_message, exit_code: exit_code, completed_at: Time.current)
  end

  # Mark this run failed and release the role + dispatch queue. Shared tail
  # for both in-process failures (ExecuteRoleJob rescue) and the watchdog
  # reaper. Safe no-op if already terminal.
  def fail_and_release!(error_message:, exit_code: 1)
    return if terminal?
    mark_failed!(error_message: error_message, exit_code: exit_code)
    release_role_and_dispatch!
  end

  def mark_cancelled!
    raise "Cannot cancel a #{status} run" if completed? || failed?
    update!(status: :cancelled, completed_at: Time.current)
  end

  def cancel!
    raise "Cannot cancel a #{status} run" if terminal?

    kill_adapter_session!
    mark_cancelled!
    task&.post_system_comment(author: role, body: "My session was cancelled before completing work.")
    release_role_and_dispatch!
  end

  # Terminates the adapter's execution session (tmux pane for claude_local,
  # no-op for adapters that don't hold an out-of-process session). Safe to
  # call multiple times.
  def kill_adapter_session!
    return unless role.claude_local?
    ClaudeLocalAdapter.kill_session("#{ClaudeLocalAdapter::SESSION_PREFIX}_#{id}")
  end

  def append_log!(text)
    return if text.blank?
    self.class.where(id: id).update_all(
      [ "log_output = COALESCE(log_output, '') || ?, last_activity_at = ?", text, Time.current ]
    )
  end

  # Overrides Runnable#mark_running! to also seed last_activity_at in the
  # same write, so the watchdog reaper has a heartbeat before any log lines
  # have streamed.
  def mark_running!
    raise "Cannot transition to running from #{status}" unless queued?
    now = Time.current
    update!(status: :running, started_at: now, last_activity_at: now)
  end

  def broadcast_line!(text)
    return if text.blank?
    append_log!(text)

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    last = @@last_broadcast_at[id] || 0

    if (now - last) >= BROADCAST_MIN_INTERVAL
      @@last_broadcast_at[id] = now
      Turbo::StreamsChannel.broadcast_append_to(
        "role_run_#{id}",
        target: "role-run-output",
        partial: "role_runs/log_line",
        locals: { text: text }
      )
    end
  end

  def broadcast_flush!
    @@last_broadcast_at.delete(id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "role_run_#{id}",
      target: "role-run-live-indicator",
      html: ""
    )
  end

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  private

  def release_role_and_dispatch!
    role.update!(status: :idle) if role.running?
    role.project.dispatch_next_throttled_run!
  end

  def terminal_status_reached?
    saved_change_to_status? && terminal?
  end
end
