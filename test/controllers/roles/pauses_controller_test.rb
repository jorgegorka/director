require "test_helper"

class Roles::PausesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @cto = roles(:cto)
  end

  # --- Pause (create) ---

  test "should pause role" do
    @cto.update_columns(status: Role.statuses[:idle])
    post role_pause_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.paused?
    assert @cto.pause_reason.present?
    assert @cto.paused_at.present?
  end

  test "should not pause already paused role" do
    @cto.update_columns(status: Role.statuses[:paused])
    post role_pause_url(@cto)
    assert_redirected_to role_url(@cto)
    assert_equal "#{@cto.title} is already paused.", flash[:alert]
  end

  test "pause responds with turbo_stream for org chart" do
    @cto.update_columns(status: Role.statuses[:idle])
    post role_pause_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.paused?
  end

  test "pause records audit event" do
    @cto.update_columns(status: Role.statuses[:idle])
    assert_difference -> { AuditEvent.where(action: "role_paused").count } do
      post role_pause_url(@cto)
    end
  end

  # --- Resume (destroy) ---

  test "should resume paused role" do
    @cto.update_columns(status: Role.statuses[:paused], pause_reason: "test", paused_at: Time.current)
    delete role_pause_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
    assert_nil @cto.pause_reason
  end

  test "should resume pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "test", paused_at: Time.current)
    delete role_pause_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
  end

  test "resume responds with turbo_stream for org chart" do
    @cto.update_columns(status: Role.statuses[:paused], pause_reason: "test", paused_at: Time.current)
    delete role_pause_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.idle?
  end

  test "resume records audit event" do
    @cto.update_columns(status: Role.statuses[:paused], pause_reason: "test", paused_at: Time.current)
    assert_difference -> { AuditEvent.where(action: "role_resumed").count } do
      delete role_pause_url(@cto)
    end
  end

  test "should not allow pause on other project roles" do
    post role_pause_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end
end
