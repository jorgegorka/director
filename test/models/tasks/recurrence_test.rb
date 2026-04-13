require "test_helper"

class Tasks::RecurrenceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:acme)
    @ceo = roles(:ceo)
    @user = users(:one)
    Current.project = @project
    @goal = @project.tasks.create!(title: "Recurring goal", creator: @ceo, assignee: @ceo)
  end

  # --- predicates ---

  test "recurring? false by default" do
    assert_not @goal.recurring?
    assert_not @goal.recurring_template?
  end

  test "recurring_template? true on root after make_recurrent" do
    @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    assert @goal.recurring?
    assert @goal.recurring_template?
  end

  # --- validations ---

  test "rejects recurrence on non-root task" do
    parent = @project.tasks.create!(title: "Parent", creator: @ceo)
    child = @project.tasks.create!(title: "Child", creator: @ceo, parent_task: parent)
    err = assert_raises(ActiveRecord::RecordInvalid) do
      child.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    end
    assert_match /Only root tasks can be recurrent/, err.message
  end

  test "rejects interval out of range" do
    err = assert_raises(ActiveRecord::RecordInvalid) do
      @goal.make_recurrent(interval: 0, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    end
    assert_match /Recurrence interval/, err.message
  end

  test "rejects unknown timezone" do
    assert_raises(ArgumentError) do
      @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "Mars/Olympus")
    end
  end

  # --- make_recurrent / stop_recurring ---

  test "make_recurrent stores anchor in UTC and snapshots timezone" do
    @goal.make_recurrent(interval: 2, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "Europe/Madrid")
    @goal.reload
    assert_equal 2, @goal.recurrence_interval
    assert_equal "week", @goal.recurrence_unit
    assert_equal "Europe/Madrid", @goal.recurrence_timezone
    expected_utc = ActiveSupport::TimeZone["Europe/Madrid"].local(2026, 4, 20, 9, 0).utc
    assert_equal expected_utc, @goal.recurrence_anchor_at
  end

  test "make_recurrent sets next_recurrence_at to next due time" do
    travel_to Time.utc(2026, 4, 19, 0, 0) do
      @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
      @goal.reload
      assert_equal Time.utc(2026, 4, 20, 9, 0), @goal.next_recurrence_at
    end
  end

  test "stop_recurring nullifies columns and clears next_recurrence_at" do
    @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    @goal.reload
    assert @goal.next_recurrence_at.present?

    @goal.stop_recurring
    @goal.reload
    assert_nil @goal.recurrence_interval
    assert_nil @goal.recurrence_unit
    assert_nil @goal.recurrence_anchor_at
    assert_nil @goal.recurrence_timezone
    assert_nil @goal.next_recurrence_at
  end

  test "make_recurrent called twice recomputes next_recurrence_at" do
    travel_to Time.utc(2026, 4, 19, 0, 0) do
      @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
      @goal.make_recurrent(interval: 1, unit: "day", anchor_date: "2026-04-20", anchor_hour: 6, timezone: "UTC")
      @goal.reload
      assert_equal Time.utc(2026, 4, 20, 6, 0), @goal.next_recurrence_at
    end
  end

  # --- due_for_recurrence? ---

  test "due_for_recurrence? always true when interval is 1" do
    @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 4, 27, 9, 0))
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 5, 4, 9, 0))
  end

  test "due_for_recurrence? skips off-cycle weeks when interval > 1" do
    @goal.make_recurrent(interval: 2, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 4, 20, 9, 0))
    assert_not @goal.due_for_recurrence?(now: Time.utc(2026, 4, 27, 9, 0))
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 5, 4, 9, 0))
  end

  test "due_for_recurrence? skips off-cycle months when interval > 1" do
    @goal.make_recurrent(interval: 3, unit: "month", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 4, 20, 9, 0))
    assert_not @goal.due_for_recurrence?(now: Time.utc(2026, 5, 20, 9, 0))
    assert @goal.due_for_recurrence?(now: Time.utc(2026, 7, 20, 9, 0))
  end

  # --- next_due_after ---

  test "next_due_after advances by interval/unit" do
    @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    after = Time.utc(2026, 4, 21, 0, 0)
    assert_equal Time.utc(2026, 4, 27, 9, 0), @goal.next_due_after(after)
  end

  # --- fire_recurrence_now ---

  test "fire_recurrence_now spawns a clone and writes spawned audit event" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_columns(status: Task.statuses[:completed], completed_at: Time.current)

    assert_difference -> { Task.where(parent_task_id: nil).count }, 1 do
      @goal.fire_recurrence_now
    end

    spawned_event = AuditEvent.where(auditable: @goal, action: "goal_recurrence_spawned").last
    assert spawned_event.present?
    clone = Task.find(spawned_event.metadata["occurrence_task_id"])
    assert_equal @goal.title, clone.title
    assert_nil clone.parent_task_id
    assert_equal "open", clone.status
    @goal.reload
    assert @goal.recurrence_last_fired_at.present?
  end

  test "fire_recurrence_now advances next_recurrence_at past now" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_columns(status: Task.statuses[:completed], completed_at: Time.current)

    @goal.fire_recurrence_now

    @goal.reload
    assert @goal.next_recurrence_at > Time.current
  end

  test "fire_recurrence_now skips when predecessor still open" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")

    assert_no_difference -> { Task.where(parent_task_id: nil).count } do
      @goal.fire_recurrence_now
    end

    skipped = AuditEvent.where(auditable: @goal, action: "goal_recurrence_skipped").last
    assert skipped.present?
    assert_equal "predecessor_open", skipped.metadata["reason"]
  end

  test "fire_recurrence_now is silent on off-cycle" do
    @goal.make_recurrent(interval: 2, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    travel_to Time.utc(2026, 4, 27, 9, 0) do
      assert_no_difference -> { AuditEvent.where(auditable: @goal).count } do
        @goal.fire_recurrence_now
      end
    end
  end

  test "fire_recurrence_later enqueues the job with task id" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    assert_enqueued_with(job: RecurrentGoalFireJob, args: [ @goal.id ]) do
      @goal.fire_recurrence_later
    end
  end

  # --- scan_due_recurrences ---

  test "scan_due_recurrences enqueues a job for each due template" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_column(:next_recurrence_at, 1.minute.ago)

    assert_enqueued_with(job: RecurrentGoalFireJob, args: [ @goal.id ]) do
      Task.scan_due_recurrences
    end
  end

  test "scan_due_recurrences advances next_recurrence_at to act as claim" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_column(:next_recurrence_at, 1.minute.ago)

    Task.scan_due_recurrences

    @goal.reload
    assert @goal.next_recurrence_at > Time.current
  end

  test "scan_due_recurrences skips tasks whose next_recurrence_at is in the future" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_column(:next_recurrence_at, 1.hour.from_now)

    assert_no_enqueued_jobs only: RecurrentGoalFireJob do
      Task.scan_due_recurrences
    end
  end

  test "scan_due_recurrences skips non-template rows" do
    @goal.update_column(:next_recurrence_at, 1.minute.ago)

    assert_no_enqueued_jobs only: RecurrentGoalFireJob do
      Task.scan_due_recurrences
    end
  end
end
