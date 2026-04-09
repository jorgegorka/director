require "test_helper"

class Roles::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @cto = roles(:cto)
  end

  # --- Approve (create) ---

  test "should approve pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required: Task creation gate is active")
    post role_approval_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.idle?
    assert_nil @cto.pause_reason
  end

  test "approve records gate_approval audit event" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    assert_difference -> { AuditEvent.where(action: "gate_approval").count } do
      post role_approval_url(@cto)
    end
  end

  test "approve responds with turbo_stream" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    post role_approval_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.idle?
  end

  # --- Reject (destroy) ---

  test "should reject pending_approval role" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    delete role_approval_url(@cto)
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert @cto.paused?
    assert_match /Approval rejected/, @cto.pause_reason
  end

  test "reject records gate_rejection audit event" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    assert_difference -> { AuditEvent.where(action: "gate_rejection").count } do
      delete role_approval_url(@cto)
    end
  end

  test "reject responds with turbo_stream" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    delete role_approval_url(@cto), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @cto.reload
    assert @cto.paused?
  end

  test "should not allow approve on other project roles" do
    post role_approval_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end
end
