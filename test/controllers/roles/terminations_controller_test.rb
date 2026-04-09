require "test_helper"

class Roles::TerminationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @cto = roles(:cto)
  end

  test "should terminate role" do
    post role_termination_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.terminated?
  end

  test "should not terminate already terminated role" do
    @cto.update_columns(status: Role.statuses[:terminated])
    post role_termination_url(@cto)
    assert_redirected_to role_url(@cto)
    assert_equal "#{@cto.title} is already terminated.", flash[:alert]
  end

  test "terminate responds with turbo_stream for org chart" do
    @cto.update_columns(status: Role.statuses[:idle])
    post role_termination_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.terminated?
  end

  test "terminate records audit event" do
    assert_difference -> { AuditEvent.where(action: "role_terminated").count } do
      post role_termination_url(@cto)
    end
  end

  test "should not allow terminate on other project roles" do
    post role_termination_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end
end
