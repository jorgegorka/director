require "test_helper"

class TaskQuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @cto = roles(:cto)
    @developer = roles(:developer)
    @widgets_lead = roles(:widgets_lead)

    # fix_login_bug is assigned to developer, developer's parent is CTO (online)
    @task = tasks(:fix_login_bug)

    # design_homepage is assigned to CTO, CTO's parent is CEO (no adapter — not online)
    @cto_task = tasks(:design_homepage)

    @unassigned_task = tasks(:write_tests)
    @widgets_task = tasks(:widgets_task)
  end

  # ==========================================================================
  # Human-initiated question tests (session auth)
  # ==========================================================================

  test "human user can ask question on behalf of assignee" do
    assert_difference [ "Message.count", "AuditEvent.count" ], 1 do
      post ask_question_task_url(@task), params: { body: "What framework should we use?" }
    end

    assert_redirected_to task_path(@task)
    assert_match "Question sent", flash[:notice]

    message = Message.where(task: @task, message_type: :question).last
    assert_equal "What framework should we use?", message.body
    assert message.question?
  end

  test "human user gets error when no manager role is online" do
    post ask_question_task_url(@cto_task), params: { body: "Need guidance" }

    assert_redirected_to task_path(@cto_task)
    assert_match "No manager", flash[:alert]
  end

  test "human user gets error for unassigned task" do
    post ask_question_task_url(@unassigned_task), params: { body: "Question?" }

    assert_redirected_to task_path(@unassigned_task)
    assert_match "No assignee", flash[:alert]
  end

  test "human user gets error for empty question body" do
    assert_no_difference "Message.count" do
      post ask_question_task_url(@task), params: { body: "" }
    end

    assert_redirected_to task_path(@task)
    assert_match "cannot be blank", flash[:alert]
  end

  test "human user cannot ask question on task from another company" do
    post ask_question_task_url(@widgets_task), params: { body: "Question?" }

    assert_redirected_to root_url
  end

  test "should redirect unauthenticated human user" do
    sign_out

    post ask_question_task_url(@task), params: { body: "Question?" }

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Role-initiated question tests (Bearer token auth)
  # ==========================================================================

  test "role can ask question via API with Bearer token" do
    sign_out

    assert_difference [ "Message.count", "AuditEvent.count" ], 1 do
      post ask_question_task_url(@task, format: :json),
           params: { body: "What testing framework should I use?" },
           headers: { "Authorization" => "Bearer #{@developer.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert json["message_id"].present?
    assert_equal @task.id, json["task_id"]

    message = Message.find(json["message_id"])
    assert message.question?
    assert_equal @developer, message.author

    event = AuditEvent.where(action: "question_asked").last
    assert_equal "Role", event.actor_type
    assert_equal @developer.id, event.actor_id
  end

  test "role asking question creates question_asked heartbeat for parent" do
    sign_out

    assert_difference -> { HeartbeatEvent.where(trigger_type: :question_asked).count }, 1 do
      post ask_question_task_url(@task, format: :json),
           params: { body: "Need clarification" },
           headers: { "Authorization" => "Bearer #{@developer.api_token}" }
    end

    event = HeartbeatEvent.where(trigger_type: :question_asked).last
    assert_equal @cto, event.role
  end

  test "role API returns error when no manager role exists" do
    sign_out

    post ask_question_task_url(@cto_task, format: :json),
         params: { body: "Need help" },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "role API returns 401 for invalid token" do
    sign_out

    post ask_question_task_url(@task, format: :json),
         params: { body: "Question?" },
         headers: { "Authorization" => "Bearer invalid_token_xyz" }

    assert_response :unauthorized
  end

  test "role API cannot ask question on task from another company" do
    sign_out

    post ask_question_task_url(@task, format: :json),
         params: { body: "Question?" },
         headers: { "Authorization" => "Bearer #{@widgets_lead.api_token}" }

    assert_response :not_found
  end
end
