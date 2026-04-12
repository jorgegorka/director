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

  test "approve persists feedback on pending hire" do
    cmo = roles(:cmo)
    cmo.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    pending_hire = pending_hires(:pending_planner_hire)

    post role_approval_url(cmo), params: { feedback: "Go ahead, looks good" }
    assert_equal "Go ahead, looks good", pending_hire.reload.feedback
  end

  test "reject persists feedback and includes it in pause_reason" do
    cmo = roles(:cmo)
    cmo.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    pending_hire = pending_hires(:pending_planner_hire)

    delete role_approval_url(cmo), params: { feedback: "Scope too broad — narrow it down" }
    cmo.reload
    assert_match(/Scope too broad/, cmo.pause_reason)
    assert_equal "Scope too broad — narrow it down", pending_hire.reload.feedback
  end

  test "approve with feedback wakes role with human_feedback on the role run" do
    cmo = roles(:cmo)
    cmo.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")

    assert_difference -> { cmo.role_runs.count }, 1 do
      post role_approval_url(cmo), params: { feedback: "Ship it — but add more tests next time." }
    end

    run = cmo.role_runs.order(:created_at).last
    assert_equal "Ship it — but add more tests next time.", run.human_feedback
    assert_equal "manual", run.trigger_type
  end

  test "approve without feedback does not wake the role" do
    cmo = roles(:cmo)
    cmo.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")

    assert_no_difference -> { cmo.role_runs.count } do
      post role_approval_url(cmo)
    end
  end

  test "reject without feedback uses generic pause_reason" do
    @cto.update_columns(status: Role.statuses[:pending_approval], pause_reason: "Approval required")
    delete role_approval_url(@cto)
    @cto.reload
    assert_equal "Approval rejected", @cto.pause_reason
  end

  test "should not allow approve on other project roles" do
    post role_approval_url(roles(:widgets_lead))
    assert_redirected_to root_url
  end
end
