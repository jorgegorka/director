require "test_helper"

class Tasks::RejectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    @task = tasks(:design_homepage)
    @creator_role = @task.creator
    @assignee_role = @task.assignee
    @other_role = roles(:developer)

    sign_in_as(@user)
    post project_switch_url(@project)
  end

  # ==========================================================================
  # Session Authentication Tests (Human Users)
  # ==========================================================================

  test "reject transitions pending_review task to open" do
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task), params: { feedback: "Needs more work" }
    @task.reload

    assert @task.open?
    assert_redirected_to @task
    assert_equal "Task rejected and returned to open.", flash[:notice]
  end

  test "reject records audit event with human user" do
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_rejection_path(@task), params: { feedback: "Needs more work" }
    end

    event = AuditEvent.where(action: "rejected").last
    assert_equal "rejected", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
    assert_equal "Needs more work", event.metadata["feedback"]
  end

  test "reject creates message when feedback provided" do
    @task.update!(status: :pending_review)

    assert_difference -> { Message.count }, 1 do
      patch task_rejection_path(@task), params: { feedback: "Please improve the design" }
    end

    message = Message.last
    assert_equal "Please improve the design", message.body
    assert_equal @task, message.task
    assert_equal @user, message.author
    assert_equal "comment", message.message_type
  end

  test "reject works without feedback" do
    @task.update!(status: :pending_review)

    assert_no_difference -> { Message.count } do
      patch task_rejection_path(@task)
    end

    @task.reload
    assert @task.open?
  end

  test "reject fails on non-pending_review task" do
    @task.update!(status: :open)

    patch task_rejection_path(@task)
    @task.reload

    assert @task.open?
    assert_redirected_to @task
    assert_equal "Task is not pending review.", flash[:alert]
  end

  test "requires authentication for session-based rejection" do
    sign_out
    @task.update!(status: :pending_review)

    assert_requires_authentication(:patch, task_rejection_path(@task))
  end

  test "prevents cross-project access with session auth" do
    @task.update!(status: :pending_review)

    assert_prevents_cross_project_access(:patch, task_rejection_path(@task))
  end

  # ==========================================================================
  # Bearer Token Authentication Tests (API)
  # ==========================================================================

  test "role can reject task via API with Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task),
          params: { feedback: "API rejection feedback" },
          headers: api_headers(@creator_role),
          as: :json

    assert_api_success_response(
      expected_task_id: @task.id,
      expected_assignee_id: @task.assignee_id,
      message_pattern: "Task rejected and returned to open."
    )

    @task.reload
    assert @task.open?
  end

  test "API rejection with feedback creates message" do
    sign_out
    @task.update!(status: :pending_review)

    assert_difference -> { Message.count }, 1 do
      patch task_rejection_path(@task),
            params: { feedback: "API feedback message" },
            headers: api_headers(@creator_role),
            as: :json
    end

    message = Message.last
    assert_equal "API feedback message", message.body
    assert_equal @creator_role, message.author
    assert_equal "comment", message.message_type
  end

  test "API rejection without feedback creates no message" do
    sign_out
    @task.update!(status: :pending_review)

    assert_no_difference -> { Message.count } do
      patch task_rejection_path(@task),
            headers: api_headers(@creator_role),
            as: :json
    end

    @task.reload
    assert @task.open?
  end

  test "API rejection records audit event with role" do
    sign_out
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_rejection_path(@task),
            params: { feedback: "Audit test feedback" },
            headers: api_headers(@creator_role),
            as: :json
    end

    event = assert_audit_event_created(action: "rejected", actor: @creator_role)
    assert_equal "Audit test feedback", event.metadata["feedback"]
    assert_equal @creator_role.title, event.metadata["reviewed_by"]
  end

  test "API rejection requires Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    assert_api_requires_bearer_token(:patch, task_rejection_path(@task))
  end

  test "API rejection rejects invalid Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    assert_api_rejects_invalid_token(:patch, task_rejection_path(@task))
  end

  test "API rejection prevents cross-project access" do
    @task.update!(status: :pending_review)

    assert_prevents_cross_project_access(:patch, task_rejection_path(@task))
  end

  # ==========================================================================
  # Authorization and Permission Tests
  # ==========================================================================

  test "API rejection requires pending_review status" do
    sign_out

    # Test each invalid status
    %i[open in_progress blocked completed cancelled].each do |invalid_status|
      @task.update!(status: invalid_status)

      patch task_rejection_path(@task),
            headers: api_headers(@creator_role),
            as: :json

      assert_api_error_response("Task is not pending review.")

      @task.reload
      assert_equal invalid_status.to_s, @task.status
    end
  end

  # ==========================================================================
  # Error Handling and Edge Cases
  # ==========================================================================

  test "API handles missing task gracefully" do
    sign_out

    assert_handles_missing_resource(:patch, "/tasks/:id/rejection")
  end

  test "API handles malformed JSON gracefully" do
    sign_out
    @task.update!(status: :pending_review)

    assert_handles_malformed_json(:patch, task_rejection_path(@task), headers: api_headers(@creator_role))
  end

  test "rejection is idempotent - already open task remains open" do
    sign_out
    @task.update!(status: :open)

    patch task_rejection_path(@task),
          params: { feedback: "Already open" },
          headers: api_headers(@creator_role),
          as: :json

    assert_api_error_response("Task is not pending review.")

    @task.reload
    assert @task.open?
  end

  # ==========================================================================
  # Feedback Parameter Handling
  # ==========================================================================

  test "handles empty feedback parameter" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task),
          params: { feedback: "" },
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok
    @task.reload
    assert @task.open?

    # Empty feedback should not create message
    assert_equal 0, Message.where(task: @task, body: "").count
  end

  test "handles whitespace-only feedback" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task),
          params: { feedback: "   \n\t   " },
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok

    # Whitespace-only feedback should not create message
    whitespace_messages = Message.where(task: @task).select { |m| m.body.match?(/\A\s*\z/) }
    assert_equal 0, whitespace_messages.count
  end

  test "handles very long feedback" do
    sign_out
    @task.update!(status: :pending_review)
    long_feedback = "A" * 10000  # Very long feedback

    patch task_rejection_path(@task),
          params: { feedback: long_feedback },
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok

    message = Message.where(task: @task).last
    assert_equal long_feedback, message.body
  end

  test "handles feedback with special characters" do
    sign_out
    @task.update!(status: :pending_review)
    special_feedback = "Feedback with émojis 🎉 and \"quotes\" and <html> tags"

    patch task_rejection_path(@task),
          params: { feedback: special_feedback },
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok

    message = Message.where(task: @task).last
    assert_equal special_feedback, message.body
  end

  # ==========================================================================
  # Boundary Condition Tests
  # ==========================================================================

  test "rejection preserves existing task metadata" do
    sign_out
    @task.update!(
      status: :pending_review,
      title: "Original Title",
      description: "Original Description",
      priority: :high
    )

    patch task_rejection_path(@task),
          params: { feedback: "Preserve metadata test" },
          headers: api_headers(@creator_role),
          as: :json

    @task.reload
    assert_equal "Original Title", @task.title
    assert_equal "Original Description", @task.description
    assert_equal "high", @task.priority
    assert @task.open?
  end

  # ==========================================================================
  # JSON Response Structure Validation
  # ==========================================================================

  test "API success response has correct JSON structure" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_rejection_path(@task),
          params: { feedback: "Test feedback" },
          headers: api_headers(@creator_role),
          as: :json

    json = response.parsed_body

    # Validate required fields
    assert_equal "ok", json["status"]
    assert_equal @task.id, json["task_id"]
    assert_equal @task.assignee_id, json["assignee_id"]
    assert_includes json["message"], "rejected"

    # Validate no unexpected fields
    expected_keys = %w[status task_id assignee_id message]
    assert_equal expected_keys.sort, json.keys.sort
  end

  test "API error response has correct JSON structure" do
    sign_out
    @task.update!(status: :completed)  # Invalid status

    patch task_rejection_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    json = response.parsed_body

    # Validate error structure
    assert json.key?("error")
    assert json["error"].is_a?(String)
    assert_includes json["error"], "not pending review"

    # Should only have error field
    assert_equal [ "error" ], json.keys
  end
end
