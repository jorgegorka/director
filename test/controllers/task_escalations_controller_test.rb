require "test_helper"

class TaskEscalationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @cto = roles(:cto)
    @developer = roles(:developer)
    @widgets_lead = roles(:widgets_lead)

    # fix_login_bug is assigned to developer
    # developer parent is CTO which is online -- escalates to cto
    @task = tasks(:fix_login_bug)

    # design_homepage is assigned to cto
    # CTO parent is CEO which has no adapter -- escalation fails
    @cto_task = tasks(:design_homepage)

    @unassigned_task = tasks(:write_tests)
    @widgets_task = tasks(:widgets_task)
  end

  # ==========================================================================
  # Human-initiated escalation tests (session auth)
  # ==========================================================================

  test "human user can escalate task to manager role" do
    assert_difference("AuditEvent.count", 1) do
      post escalate_task_url(@task)
    end

    assert_redirected_to task_path(@task)
    assert_equal "Task escalated to #{@cto.title}.", flash[:notice]

    @task.reload
    assert_equal @cto, @task.assignee

    event = AuditEvent.where(action: "escalated").last
    assert_equal "escalated", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal @developer.id, event.metadata["from_role_id"]
    assert_equal @cto.id, event.metadata["to_role_id"]
  end

  test "human user cannot escalate when no manager role is online" do
    original_assignee = @cto_task.assignee

    post escalate_task_url(@cto_task)

    assert_redirected_to task_path(@cto_task)
    assert_match "Cannot escalate", flash[:alert]

    @cto_task.reload
    assert_equal original_assignee, @cto_task.assignee
  end

  test "human user cannot escalate unassigned task" do
    post escalate_task_url(@unassigned_task)

    assert_redirected_to task_path(@unassigned_task)
    assert_match "Cannot escalate", flash[:alert]

    @unassigned_task.reload
    assert_nil @unassigned_task.assignee
  end

  test "human user escalation records reason in audit" do
    post escalate_task_url(@task), params: { reason: "Needs manager attention" }

    event = AuditEvent.where(action: "escalated").last
    assert_equal "Needs manager attention", event.metadata["reason"]
  end

  test "human user cannot escalate task from another company" do
    post escalate_task_url(@widgets_task)

    assert_redirected_to root_url
  end

  test "should redirect unauthenticated human user" do
    sign_out

    post escalate_task_url(@task)

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Role-initiated escalation tests (Bearer token auth)
  # ==========================================================================

  test "role can escalate task via API with Bearer token" do
    sign_out

    assert_difference("AuditEvent.count", 1) do
      post escalate_task_url(@task, format: :json),
           headers: { "Authorization" => "Bearer #{@developer.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]

    @task.reload
    assert_equal @cto, @task.assignee

    event = AuditEvent.where(action: "escalated").last
    assert_equal "Role", event.actor_type
    assert_equal @developer.id, event.actor_id
  end

  test "role API escalation returns JSON error when no manager role exists" do
    sign_out
    original_assignee = @cto_task.assignee

    post escalate_task_url(@cto_task, format: :json),
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?

    @cto_task.reload
    assert_equal original_assignee, @cto_task.assignee
  end

  test "role API escalation returns 401 for invalid token" do
    sign_out

    post escalate_task_url(@task, format: :json),
         headers: { "Authorization" => "Bearer invalid_token_xyz" }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "role API cannot escalate task from another company" do
    sign_out

    post escalate_task_url(@task, format: :json),
         headers: { "Authorization" => "Bearer #{@widgets_lead.api_token}" }

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end
end
