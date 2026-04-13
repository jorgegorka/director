require "test_helper"

class RecurrentTaskScannerJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:acme)
    @ceo = roles(:ceo)
    Current.project = @project
    @goal = @project.tasks.create!(title: "Recurring goal", creator: @ceo, assignee: @ceo)
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: Date.current.to_s, anchor_hour: 9, timezone: "UTC")
    @goal.update_column(:next_recurrence_at, 1.minute.ago)
  end

  test "delegates to Task.scan_due_recurrences" do
    assert_enqueued_with(job: RecurrentGoalFireJob, args: [ @goal.id ]) do
      RecurrentTaskScannerJob.perform_now
    end
  end
end
