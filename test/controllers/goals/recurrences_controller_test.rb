require "test_helper"

class Goals::RecurrencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @root_task = tasks(:design_homepage)
  end

  test "destroy stops recurrence" do
    @root_task.make_recurrent(interval: 1, unit: "week", anchor_date: "2026-04-20", anchor_hour: 9, timezone: "UTC")
    delete goal_recurrence_url(@root_task)
    assert_redirected_to goal_url(@root_task)
    assert_not @root_task.reload.recurring?
  end
end
