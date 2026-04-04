require "test_helper"

class RoleRunTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @developer = roles(:developer)
    @task = tasks(:design_homepage)
    @company = companies(:acme)
    @queued_run = role_runs(:queued_run)
    @running_run = role_runs(:running_run)
    @completed_run = role_runs(:completed_run)
    @failed_run = role_runs(:failed_run)
  end

  # --- Validations ---

  test "valid with role, company, and status" do
    run = RoleRun.new(role: @role, company: @company, status: :queued)
    assert run.valid?
  end

  test "valid with optional task nil" do
    run = RoleRun.new(role: @role, company: @company, status: :queued, task: nil)
    assert run.valid?
  end

  test "invalid without role" do
    run = RoleRun.new(role: nil, company: @company, status: :queued)
    assert_not run.valid?
    assert_includes run.errors[:role], "must exist"
  end

  test "invalid without company" do
    run = RoleRun.new(role: @role, company: nil, status: :queued)
    assert_not run.valid?
    assert_includes run.errors[:company], "must exist"
  end

  # --- Associations ---

  test "belongs to role" do
    assert_equal @role, @queued_run.role
  end

  test "belongs to task (optional)" do
    assert_equal tasks(:design_homepage), @queued_run.task
  end

  test "nil task is valid" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued, task: nil)
    assert_nil run.task
    assert run.valid?
  end

  test "belongs to company" do
    assert_equal @company, @queued_run.company
  end

  # --- Enum ---

  test "status enum: queued?" do
    assert @queued_run.queued?
  end

  test "status enum: running?" do
    assert @running_run.running?
  end

  test "status enum: completed?" do
    assert @completed_run.completed?
  end

  test "status enum: failed?" do
    assert @failed_run.failed?
  end

  test "status enum: cancelled?" do
    run = RoleRun.new(status: :cancelled)
    assert run.cancelled?
  end

  test "status enum covers all values" do
    %i[queued running completed failed cancelled].each do |s|
      run = RoleRun.new(status: s)
      assert run.send(:"#{s}?"), "Expected #{s}? to return true"
    end
  end

  # --- Scopes ---

  test "for_role filters by role" do
    runs = RoleRun.for_role(@role)
    assert runs.all? { |r| r.role_id == @role.id }
    assert_includes runs, @queued_run
    assert_not_includes runs, @running_run
  end

  test "active returns queued and running runs" do
    active = RoleRun.active
    assert_includes active, @queued_run
    assert_includes active, @running_run
    assert_not_includes active, @completed_run
    assert_not_includes active, @failed_run
  end

  test "terminal returns completed, failed, and cancelled runs" do
    terminal = RoleRun.terminal
    assert_includes terminal, @completed_run
    assert_includes terminal, @failed_run
    assert_not_includes terminal, @queued_run
    assert_not_includes terminal, @running_run
  end

  test "recent filters by 24 hours" do
    old_run = RoleRun.create!(
      role: @role, company: @company, status: :queued,
      created_at: 25.hours.ago
    )
    recent = RoleRun.recent
    assert_includes recent, @queued_run
    assert_not_includes recent, old_run
  end

  test "chronological orders by created_at ascending" do
    runs = RoleRun.chronological
    timestamps = runs.map(&:created_at)
    assert_equal timestamps, timestamps.sort
  end

  test "reverse_chronological orders by created_at descending" do
    runs = RoleRun.reverse_chronological
    timestamps = runs.map(&:created_at)
    assert_equal timestamps, timestamps.sort.reverse
  end

  test "for_current_company filters by Current.company" do
    Current.company = @company
    runs = RoleRun.for_current_company
    assert runs.all? { |r| r.company_id == @company.id }
  ensure
    Current.company = nil
  end

  # --- mark_running! ---

  test "mark_running! transitions from queued to running" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued)
    assert run.queued?
    run.mark_running!
    assert run.running?
  end

  test "mark_running! sets started_at" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued)
    assert_nil run.started_at
    run.mark_running!
    assert_not_nil run.started_at
  end

  test "mark_running! sets last_activity_at so watchdog sees a heartbeat" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued)
    assert_nil run.last_activity_at
    run.mark_running!
    assert_not_nil run.last_activity_at
    assert_in_delta Time.current.to_f, run.last_activity_at.to_f, 2.0
  end

  test "mark_running! raises from running" do
    assert_raises(RuntimeError) { @running_run.mark_running! }
  end

  test "mark_running! raises from completed" do
    assert_raises(RuntimeError) { @completed_run.mark_running! }
  end

  test "mark_running! raises from failed" do
    assert_raises(RuntimeError) { @failed_run.mark_running! }
  end

  test "mark_running! raises from cancelled" do
    run = RoleRun.create!(role: @role, company: @company, status: :cancelled)
    assert_raises(RuntimeError) { run.mark_running! }
  end

  # --- mark_completed! ---

  test "mark_completed! transitions to completed" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_completed!
    assert run.completed?
  end

  test "mark_completed! sets completed_at" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_completed!
    assert_not_nil run.completed_at
  end

  test "mark_completed! accepts optional exit_code" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_completed!(exit_code: 0)
    assert_equal 0, run.exit_code
  end

  test "mark_completed! accepts optional cost_cents" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_completed!(cost_cents: 500)
    assert_equal 500, run.cost_cents
  end

  test "mark_completed! accepts optional claude_session_id" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_completed!(claude_session_id: "sess_new_456")
    assert_equal "sess_new_456", run.claude_session_id
  end

  test "mark_completed! preserves existing claude_session_id if not passed" do
    run = RoleRun.create!(
      role: @role, company: @company, status: :running,
      started_at: 1.minute.ago, claude_session_id: "sess_existing"
    )
    run.mark_completed!
    assert_equal "sess_existing", run.claude_session_id
  end

  # --- mark_failed! ---

  test "mark_failed! transitions to failed" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_failed!(error_message: "Something went wrong")
    assert run.failed?
  end

  test "mark_failed! sets error_message" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_failed!(error_message: "Connection timeout")
    assert_equal "Connection timeout", run.error_message
  end

  test "mark_failed! sets completed_at" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_failed!(error_message: "Error")
    assert_not_nil run.completed_at
  end

  test "mark_failed! accepts optional exit_code" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_failed!(error_message: "Error", exit_code: 2)
    assert_equal 2, run.exit_code
  end

  # --- mark_cancelled! ---

  test "mark_cancelled! transitions from queued to cancelled" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued)
    run.mark_cancelled!
    assert run.cancelled?
  end

  test "mark_cancelled! transitions from running to cancelled" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.mark_cancelled!
    assert run.cancelled?
  end

  test "mark_cancelled! sets completed_at" do
    run = RoleRun.create!(role: @role, company: @company, status: :queued)
    run.mark_cancelled!
    assert_not_nil run.completed_at
  end

  test "mark_cancelled! raises from completed" do
    assert_raises(RuntimeError) { @completed_run.mark_cancelled! }
  end

  test "mark_cancelled! raises from failed" do
    assert_raises(RuntimeError) { @failed_run.mark_cancelled! }
  end

  # --- append_log! ---

  test "append_log! appends text to nil log_output" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    assert_nil run.log_output
    run.append_log!("Hello world\n")
    assert_equal "Hello world\n", run.reload.log_output
  end

  test "append_log! appends text to existing log_output" do
    run = RoleRun.create!(
      role: @role, company: @company, status: :running,
      started_at: 1.minute.ago, log_output: "Line 1\n"
    )
    run.append_log!("Line 2\n")
    assert_equal "Line 1\nLine 2\n", run.reload.log_output
  end

  test "append_log! ignores blank text" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.append_log!("")
    assert_nil run.log_output
  end

  test "append_log! ignores nil text" do
    run = RoleRun.create!(role: @role, company: @company, status: :running, started_at: 1.minute.ago)
    run.append_log!(nil)
    assert_nil run.log_output
  end

  test "append_log! bumps last_activity_at" do
    run = RoleRun.create!(
      role: @role, company: @company, status: :running,
      started_at: 10.minutes.ago, last_activity_at: 10.minutes.ago
    )
    stale = run.last_activity_at
    travel 1.second do
      run.append_log!("line\n")
    end
    assert_operator run.reload.last_activity_at, :>, stale
  end

  test "append_log! ignoring blank text does not bump last_activity_at" do
    run = RoleRun.create!(
      role: @role, company: @company, status: :running,
      started_at: 10.minutes.ago, last_activity_at: 10.minutes.ago
    )
    before = run.last_activity_at
    run.append_log!("")
    assert_equal before.to_i, run.reload.last_activity_at.to_i
  end

  # --- broadcast_line! ---

  test "broadcast_line! persists text via append_log!" do
    run = role_runs(:running_run)
    run.update_columns(log_output: nil)
    run.broadcast_line!("hello world\n")
    assert_equal "hello world\n", run.reload.log_output
  end

  test "broadcast_line! skips blank text" do
    run = role_runs(:running_run)
    run.update_columns(log_output: "existing\n")
    run.broadcast_line!("")
    run.broadcast_line!(nil)
    assert_equal "existing\n", run.reload.log_output
  end

  test "broadcast_line! broadcasts to role_run stream" do
    run = role_runs(:running_run)
    assert_nothing_raised { run.broadcast_line!("test line\n") }
  end

  # --- cancel! ---

  test "cancel! marks run as cancelled and returns role to idle" do
    role = roles(:cto)
    role.update!(status: :running)
    run = role.role_runs.create!(
      company: companies(:acme),
      status: :running,
      trigger_type: "task_assigned",
      started_at: Time.current
    )

    killed = []
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |name| killed << name }

    run.cancel!

    assert run.cancelled?
    assert_not_nil run.completed_at
    assert role.reload.idle?
    assert_equal [ "director_run_#{run.id}" ], killed
  ensure
    if ClaudeLocalAdapter.singleton_class.method_defined?(:kill_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:kill_session)
    end
  end

  test "cancel! on HTTP role skips tmux kill" do
    role = roles(:developer)
    role.update!(status: :running)
    run = role.role_runs.create!(
      company: companies(:acme),
      status: :running,
      trigger_type: "task_assigned",
      started_at: Time.current
    )

    run.cancel!

    assert run.cancelled?
    assert role.reload.idle?
  end

  test "cancel! raises on already completed run" do
    run = role_runs(:completed_run)
    assert_raises(RuntimeError) { run.cancel! }
  end

  test "cancel! posts message to task when task present" do
    role = roles(:cto)
    role.update!(status: :running)
    task = tasks(:design_homepage)
    run = role.role_runs.create!(
      company: companies(:acme),
      status: :running,
      trigger_type: "task_assigned",
      task: task,
      started_at: Time.current
    )

    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |_name| true }

    assert_difference "Message.count", 1 do
      run.cancel!
    end

    message = task.messages.last
    assert_equal role, message.author
    assert_match(/cancelled/, message.body)
  ensure
    if ClaudeLocalAdapter.singleton_class.method_defined?(:kill_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:kill_session)
    end
  end

  test "cancel! does not post message when no task" do
    role = roles(:cto)
    role.update!(status: :running)
    run = role.role_runs.create!(
      company: companies(:acme),
      status: :running,
      trigger_type: "scheduled",
      task: nil,
      started_at: Time.current
    )

    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |_name| true }

    assert_no_difference "Message.count" do
      run.cancel!
    end
  ensure
    if ClaudeLocalAdapter.singleton_class.method_defined?(:kill_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:kill_session)
    end
  end

  # --- broadcast batching ---

  test "broadcast_line! persists every line regardless of batching" do
    run = role_runs(:running_run)
    run.update_columns(log_output: nil)
    5.times { |i| run.broadcast_line!("line #{i}\n") }
    assert_equal 5, run.reload.log_output.scan("\n").count
  end

  test "broadcast_flush! cleans up tracking state" do
    run = role_runs(:running_run)
    run.broadcast_line!("test\n")
    run.broadcast_flush!
    assert_nothing_raised { run.broadcast_line!("after flush\n") }
  end

  # --- tool-use detection ---

  test "broadcast_line! handles stream-json tool-use events" do
    run = role_runs(:running_run)
    tool_json = '{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_123","name":"Bash"}}'
    assert_nothing_raised { run.broadcast_line!(tool_json + "\n") }
  end

  # --- terminal status flush ---

  test "broadcast_flush! called when run reaches terminal state" do
    run = role_runs(:running_run)
    run.mark_completed!(exit_code: 0)
    assert_nothing_raised { run.broadcast_line!("post-terminal\n") }
  end

  # --- duration_seconds ---

  test "duration_seconds returns elapsed seconds" do
    duration = @completed_run.duration_seconds
    assert_not_nil duration
    assert_kind_of Numeric, duration
    assert duration > 0
  end

  test "duration_seconds returns nil when started_at is nil" do
    run = RoleRun.new(completed_at: Time.current)
    assert_nil run.duration_seconds
  end

  test "duration_seconds returns nil when completed_at is nil" do
    run = RoleRun.new(started_at: Time.current)
    assert_nil run.duration_seconds
  end

  # --- terminal? ---

  test "terminal? returns true for completed" do
    assert @completed_run.terminal?
  end

  test "terminal? returns true for failed" do
    assert @failed_run.terminal?
  end

  test "terminal? returns true for cancelled" do
    run = RoleRun.new(status: :cancelled)
    assert run.terminal?
  end

  test "terminal? returns false for queued" do
    assert_not @queued_run.terminal?
  end

  test "terminal? returns false for running" do
    assert_not @running_run.terminal?
  end

  # --- Role association ---

  test "role.role_runs returns associated runs" do
    runs = @role.role_runs
    assert_includes runs, @queued_run
    assert_includes runs, @completed_run
  end

  test "role.latest_session_id returns most recent session id" do
    session_id = @role.latest_session_id
    assert_equal "sess_abc123", session_id
  end

  test "role.latest_session_id returns nil when no runs have session ids" do
    role = roles(:developer)
    RoleRun.where(role: role).update_all(claude_session_id: nil)
    assert_nil role.latest_session_id
  end
end
