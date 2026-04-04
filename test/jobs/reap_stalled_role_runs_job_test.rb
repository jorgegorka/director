require "test_helper"

class ReapStalledRoleRunsJobTest < ActiveSupport::TestCase
  setup do
    @role = roles(:developer)
    @company = companies(:acme)
    @task = tasks(:fix_login_bug)

    # Capture kill_session calls so we can assert on them without touching tmux.
    @killed_sessions = []
    killed = @killed_sessions
    ClaudeLocalAdapter.define_singleton_method(:kill_session) do |name|
      killed << name
      true
    end
  end

  teardown do
    if ClaudeLocalAdapter.singleton_class.method_defined?(:kill_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:kill_session)
    end
  end

  # --- Selection ---

  test "reaps running run whose last_activity_at is older than threshold" do
    run = create_running_run(last_activity_at: 10.minutes.ago)

    ReapStalledRoleRunsJob.perform_now

    assert run.reload.failed?
    assert_match(/Reaped by watchdog/, run.error_message)
    assert_equal 1, run.exit_code
    assert_not_nil run.completed_at
  end

  test "leaves running run alone when last_activity_at is fresh" do
    run = create_running_run(last_activity_at: 30.seconds.ago)

    ReapStalledRoleRunsJob.perform_now

    assert run.reload.running?
    assert_nil run.error_message
  end

  test "leaves running run alone when last_activity_at is exactly at threshold boundary" do
    # 4m59s ago should NOT be reaped (threshold is 5m)
    run = create_running_run(last_activity_at: (5.minutes - 1.second).ago)

    ReapStalledRoleRunsJob.perform_now

    assert run.reload.running?
  end

  test "ignores terminal runs regardless of last_activity_at" do
    completed = role_runs(:completed_run)
    completed.update_columns(last_activity_at: 1.hour.ago)
    failed = role_runs(:failed_run)
    failed.update_columns(last_activity_at: 1.hour.ago)

    assert_nothing_raised { ReapStalledRoleRunsJob.perform_now }

    assert completed.reload.completed?
    assert failed.reload.failed?
  end

  test "ignores queued runs even if last_activity_at is stale" do
    run = RoleRun.create!(
      role: @role, company: @company, task: @task,
      status: :queued, last_activity_at: 1.hour.ago
    )

    ReapStalledRoleRunsJob.perform_now

    assert run.reload.queued?
  end

  test "ignores running run with nil last_activity_at" do
    # Defensive: older rows from before the migration should not be reaped
    # on the very first watchdog tick. They'll be picked up once they stream
    # any output or are dispatched fresh.
    run = RoleRun.create!(
      role: @role, company: @company, task: @task,
      status: :running, started_at: 1.hour.ago, last_activity_at: nil
    )

    ReapStalledRoleRunsJob.perform_now

    assert run.reload.running?
  end

  # --- Side effects ---

  test "kills tmux session for stalled claude_local run" do
    cto = roles(:cto) # cto fixture is adapter_type: claude_local
    run = create_running_run(last_activity_at: 10.minutes.ago, role: cto)

    ReapStalledRoleRunsJob.perform_now

    assert_includes @killed_sessions, "#{ClaudeLocalAdapter::SESSION_PREFIX}_#{run.id}"
  end

  test "does not call kill_session for non-claude_local runs" do
    # @role is developer fixture which is adapter_type: http
    create_running_run(last_activity_at: 10.minutes.ago)

    ReapStalledRoleRunsJob.perform_now

    assert_empty @killed_sessions
  end

  test "posts a notification message on the task when reaping" do
    run = create_running_run(last_activity_at: 10.minutes.ago)

    assert_difference -> { run.task.messages.count }, +1 do
      ReapStalledRoleRunsJob.perform_now
    end

    msg = run.task.messages.order(:created_at).last
    assert_match(/watchdog/i, msg.body)
  end

  test "transitions role back to idle" do
    @role.update!(status: :running)
    create_running_run(last_activity_at: 10.minutes.ago)

    ReapStalledRoleRunsJob.perform_now

    assert @role.reload.idle?
  end

  test "reaps multiple stalled runs in one pass" do
    run1 = create_running_run(last_activity_at: 10.minutes.ago)
    run2 = create_running_run(last_activity_at: 20.minutes.ago, role: roles(:cto))

    ReapStalledRoleRunsJob.perform_now

    assert run1.reload.failed?
    assert run2.reload.failed?
  end

  test "isolated failures do not prevent reaping other runs" do
    run1 = create_running_run(last_activity_at: 10.minutes.ago)
    run2 = create_running_run(last_activity_at: 10.minutes.ago, role: roles(:cto))

    # Make mark_failed! blow up on run1 only
    original = RoleRun.instance_method(:mark_failed!)
    RoleRun.define_method(:mark_failed!) do |**kwargs|
      raise "boom" if id == run1.id
      original.bind(self).call(**kwargs)
    end

    begin
      assert_nothing_raised { ReapStalledRoleRunsJob.perform_now }
      assert run1.reload.running?, "run1 should remain running because its reap failed"
      assert run2.reload.failed?,  "run2 should still be reaped despite run1's failure"
    ensure
      RoleRun.define_method(:mark_failed!, original)
    end
  end

  private

  def create_running_run(last_activity_at:, role: @role)
    RoleRun.create!(
      role: role,
      company: @company,
      task: @task,
      status: :running,
      started_at: 1.hour.ago,
      last_activity_at: last_activity_at
    )
  end
end
