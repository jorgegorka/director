require "test_helper"

class TaskDelegationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)

    @cto = roles(:cto)
    @developer = roles(:developer)
    @process_role = roles(:process_role)
    @widgets_lead = roles(:widgets_lead)

    # design_homepage is assigned to cto
    # developer role is subordinate to cto -- can delegate to developer
    @task = tasks(:design_homepage)
    @widgets_task = tasks(:widgets_task)
    @unassigned_task = tasks(:write_tests)
  end

  # ==========================================================================
  # Human-initiated delegation tests (session auth)
  # ==========================================================================

  test "human user can delegate task to subordinate role" do
    assert_difference("AuditEvent.count", 1) do
      post delegate_task_url(@task), params: { role_id: @developer.id }
    end

    assert_redirected_to task_path(@task)
    assert_equal "Task delegated to #{@developer.title}.", flash[:notice]

    @task.reload
    assert_equal @developer, @task.assignee

    event = AuditEvent.where(action: "delegated").last
    assert_equal "delegated", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal @cto.id, event.metadata["from_role_id"]
    assert_equal @developer.id, event.metadata["to_role_id"]
  end

  test "human user cannot delegate to role not in subordinate hierarchy" do
    original_assignee = @task.assignee

    # CEO is parent of CTO, not a subordinate — delegation should fail
    post delegate_task_url(@task), params: { role_id: @cto.parent.id }

    assert_redirected_to task_path(@task)
    assert_match "Cannot delegate", flash[:alert]

    @task.reload
    assert_equal original_assignee, @task.assignee
  end

  test "human user cannot delegate unassigned task" do
    post delegate_task_url(@unassigned_task), params: { role_id: @developer.id }

    assert_redirected_to task_path(@unassigned_task)
    assert_match "Cannot delegate", flash[:alert]

    @unassigned_task.reload
    assert_nil @unassigned_task.assignee
  end

  test "human user delegation records reason in audit metadata" do
    post delegate_task_url(@task), params: { role_id: @developer.id, reason: "Delegating to senior developer" }

    event = AuditEvent.where(action: "delegated").last
    assert_equal "Delegating to senior developer", event.metadata["reason"]
  end

  test "human user cannot delegate task from another project" do
    post delegate_task_url(@widgets_task), params: { role_id: @developer.id }

    assert_redirected_to root_url
  end

  test "should redirect unauthenticated human user" do
    sign_out

    post delegate_task_url(@task), params: { role_id: @developer.id }

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Role-initiated delegation tests (Bearer token auth)
  # ==========================================================================

  test "role can delegate task via API with Bearer token" do
    sign_out

    assert_difference("AuditEvent.count", 1) do
      post delegate_task_url(@task, format: :json),
           params: { role_id: @developer.id },
           headers: { "Authorization" => "Bearer #{@cto.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert_equal @task.id, json["task_id"]

    @task.reload
    assert_equal @developer, @task.assignee

    event = AuditEvent.where(action: "delegated").last
    assert_equal "Role", event.actor_type
    assert_equal @cto.id, event.actor_id
  end

  test "role API delegation returns JSON error for invalid target" do
    sign_out
    original_assignee = @task.assignee

    # CEO is parent of CTO, not a subordinate — delegation should fail
    ceo = roles(:ceo)
    post delegate_task_url(@task, format: :json),
         params: { role_id: ceo.id },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?

    @task.reload
    assert_equal original_assignee, @task.assignee
  end

  test "role API returns 401 for invalid Bearer token" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { role_id: @developer.id },
         headers: { "Authorization" => "Bearer invalid_token_xyz" }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "role API returns 401 for missing Authorization header" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { role_id: @developer.id }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "role API sets Current.project from role project" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { role_id: @developer.id },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :ok
    @task.reload
    assert_equal @developer, @task.assignee
  end

  test "role API cannot delegate task from another project" do
    sign_out

    post delegate_task_url(@task, format: :json),
         params: { role_id: @developer.id },
         headers: { "Authorization" => "Bearer #{@widgets_lead.api_token}" }

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end
end
