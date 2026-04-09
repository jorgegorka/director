require "test_helper"

class Roles::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @cto = roles(:cto)
  end

  test "should run idle role" do
    @cto.update_columns(status: Role.statuses[:idle])
    @cto.role_runs.active.update_all(status: RoleRun.statuses[:cancelled])
    assert_difference("RoleRun.count") do
      post role_activity_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_match /has been started/, flash[:notice]
  end

  test "should not run terminated role" do
    @cto.update_columns(status: Role.statuses[:terminated])
    assert_no_difference("RoleRun.count") do
      post role_activity_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_equal "Cannot run a terminated role.", flash[:alert]
  end

  test "should not run role with active run" do
    @cto.update_columns(status: Role.statuses[:idle])
    @cto.role_runs.create!(project: @project, status: :queued, trigger_type: :scheduled)
    assert_no_difference("RoleRun.count") do
      post role_activity_url(@cto)
    end
    assert_redirected_to role_url(@cto)
    assert_match /already has an active run/, flash[:alert]
  end

  test "run responds with turbo_stream for org chart" do
    @cto.update_columns(status: Role.statuses[:idle])
    @cto.role_runs.active.update_all(status: RoleRun.statuses[:cancelled])
    post role_activity_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "should not allow run on other project roles" do
    post role_activity_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end
end
