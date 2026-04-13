require "test_helper"

class RecurrentGoalFireJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:acme)
    @ceo = roles(:ceo)
    Current.project = @project
    @goal = @project.tasks.create!(title: "Recurring goal", creator: @ceo, assignee: @ceo)
  end

  test "performs by delegating to fire_recurrence_now" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_columns(status: Task.statuses[:completed], completed_at: Time.current)

    assert_difference -> { Task.where(parent_task_id: nil).count }, 1 do
      RecurrentGoalFireJob.perform_now(@goal.id)
    end
  end

  test "no-ops on missing task id" do
    assert_nothing_raised do
      RecurrentGoalFireJob.perform_now(0)
    end
  end
end
