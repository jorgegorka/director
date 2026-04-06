class ReapStalledRoleRunsJob < ApplicationJob
  queue_as :default

  # Absolute ceiling above ClaudeLocalAdapter::MAX_POLL_WAIT (300s). The
  # in-process stall detector (60s) normally handles stalls; the watchdog only
  # catches runs where that detector failed to fire -- e.g. worker crash,
  # machine reboot, host suspend freezing the monotonic clock, or tmux going
  # unreachable.
  STALL_THRESHOLD = 5.minutes

  def perform
    RoleRun.where(status: :running)
           .where("last_activity_at < ?", STALL_THRESHOLD.ago)
           .includes(:task, role: :project)
           .find_each { |run| reap(run) }
  end

  private

  def reap(role_run)
    elapsed = (Time.current - role_run.last_activity_at).to_i
    Rails.logger.warn("[ReapStalledRoleRunsJob] reaping RoleRun##{role_run.id} (#{elapsed}s since last activity)")

    role_run.kill_adapter_session!
    role_run.fail_and_release!(
      error_message: "Reaped by watchdog: no activity for #{elapsed} seconds",
      exit_code: 1
    )
    role_run.task&.post_system_comment(
      author: role_run.role,
      body: "My session was terminated by the watchdog after going silent."
    )
  rescue StandardError => e
    # Don't let one stuck run prevent reaping others.
    Rails.logger.error("[ReapStalledRoleRunsJob] failed to reap RoleRun##{role_run.id}: #{e.class}: #{e.message}")
  end
end
