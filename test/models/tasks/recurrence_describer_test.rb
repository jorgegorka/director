require "test_helper"

class Tasks::RecurrenceDescriberTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @ceo = roles(:ceo)
    Current.project = @project
    @goal = @project.tasks.create!(title: "Recurring goal", creator: @ceo, assignee: @ceo)
  end

  test "nil for non-recurring" do
    assert_nil Tasks::RecurrenceDescriber.new(@goal).to_sentence
  end

  test "weekly with N=1 names the weekday" do
    @goal.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "Europe/Madrid")
    assert_equal "Repeats every week on Monday at 09:00 (Europe/Madrid)",
      Tasks::RecurrenceDescriber.new(@goal).to_sentence
  end

  test "biweekly pluralizes" do
    @goal.make_recurrent(interval: 2, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    assert_equal "Repeats every 2 weeks on Monday at 09:00 (UTC)",
      Tasks::RecurrenceDescriber.new(@goal).to_sentence
  end

  test "monthly names day-of-month" do
    @goal.make_recurrent(interval: 1, unit: "month", anchor_date: "2026-04-20", anchor_hour: 8, timezone: "UTC")
    assert_equal "Repeats every month on day 20 at 08:00 (UTC)",
      Tasks::RecurrenceDescriber.new(@goal).to_sentence
  end

  test "daily omits anchor weekday/day" do
    @goal.make_recurrent(interval: 1, unit: "day", anchor_date: "2026-04-20", anchor_hour: 7, timezone: "UTC")
    assert_equal "Repeats every day at 07:00 (UTC)",
      Tasks::RecurrenceDescriber.new(@goal).to_sentence
  end
end
