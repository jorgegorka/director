require "test_helper"

class Tasks::ApprovalsControllerTest < ActionDispatch::IntegrationTest
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

  test "approve transitions pending_review task to completed" do
    @task.update!(status: :pending_review)

    patch task_approval_path(@task)
    @task.reload

    assert @task.completed?
    assert_not_nil @task.reviewed_at
    assert_redirected_to @task
    assert_equal "Task approved and marked as completed.", flash[:notice]
  end

  test "approve records audit event with human user" do
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_approval_path(@task)
    end

    event = AuditEvent.where(action: "approved").last
    assert_equal "approved", event.action
    assert_equal "User", event.actor_type
    assert_equal @user.id, event.actor_id
  end

  test "approve fails on non-pending_review task" do
    @task.update!(status: :open)

    patch task_approval_path(@task)
    @task.reload

    assert @task.open?
    assert_redirected_to @task
    assert_equal "Task is not pending review.", flash[:alert]
  end

  test "requires authentication for session-based approval" do
    sign_out
    @task.update!(status: :pending_review)

    assert_requires_authentication(:patch, task_approval_path(@task))
  end

  test "prevents cross-project access with session auth" do
    @task.update!(status: :pending_review)

    assert_prevents_cross_project_access(:patch, task_approval_path(@task))
  end

  # ==========================================================================
  # Bearer Token Authentication Tests (API)
  # ==========================================================================

  test "role can approve task via API with Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    assert_api_success_response(
      expected_task_id: @task.id,
      expected_assignee_id: @task.assignee_id,
      message_pattern: "Task approved and marked as completed."
    )

    @task.reload
    assert @task.completed?
    assert_not_nil @task.reviewed_at
    assert_equal @creator_role, @task.reviewed_by
  end

  test "API approval records audit event with role" do
    sign_out
    @task.update!(status: :pending_review)

    assert_difference -> { AuditEvent.count }, 1 do
      patch task_approval_path(@task),
            headers: api_headers(@creator_role),
            as: :json
    end

    event = assert_audit_event_created(action: "approved", actor: @creator_role)
    assert_equal @creator_role.title, event.metadata["reviewed_by"]
  end

  test "API approval requires Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    assert_api_requires_bearer_token(:patch, task_approval_path(@task))
  end

  test "API approval rejects invalid Bearer token" do
    sign_out
    @task.update!(status: :pending_review)

    assert_api_rejects_invalid_token(:patch, task_approval_path(@task))
  end

  test "API approval prevents cross-project access" do
    @task.update!(status: :pending_review)

    assert_prevents_cross_project_access(:patch, task_approval_path(@task))
  end

  # ==========================================================================
  # Authorization and Permission Tests
  # ==========================================================================

  test "API approval requires pending_review status" do
    sign_out

    # Test each invalid status
    %i[open in_progress blocked completed cancelled].each do |invalid_status|
      @task.update!(status: invalid_status)

      patch task_approval_path(@task),
            headers: api_headers(@creator_role),
            as: :json

      assert_api_error_response("Task is not pending review.")

      @task.reload
      assert_equal invalid_status.to_s, @task.status
    end
  end

  test "API handles task creator permission properly" do
    sign_out
    @task.update!(status: :pending_review)

    # Task creator (role) should be able to approve
    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok
  end

  # ==========================================================================
  # Error Handling and Edge Cases
  # ==========================================================================

  test "API handles missing task gracefully" do
    sign_out

    assert_handles_missing_resource(:patch, "/tasks/:id/approval")
  end

  test "API handles malformed JSON gracefully" do
    sign_out
    @task.update!(status: :pending_review)

    assert_handles_malformed_json(:patch, task_approval_path(@task), headers: api_headers(@creator_role))
  end

  test "approval is idempotent - already completed task remains completed" do
    sign_out
    @task.update!(status: :completed, reviewed_by: @creator_role, reviewed_at: 1.hour.ago)
    original_reviewed_at = @task.reviewed_at

    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    assert_api_error_response("Task is not pending review.")

    @task.reload
    assert @task.completed?
    assert_equal original_reviewed_at.to_i, @task.reviewed_at.to_i
  end

  # ==========================================================================
  # Boundary Condition Tests
  # ==========================================================================

  test "approval works with minimum required data" do
    sign_out
    @task.update!(status: :pending_review)

    # Test with just the bare minimum - no extra params
    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    assert_response :ok
    @task.reload
    assert @task.completed?
  end

  test "approval preserves existing task metadata" do
    sign_out
    @task.update!(
      status: :pending_review,
      title: "Original Title",
      description: "Original Description",
      priority: :high
    )

    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    @task.reload
    assert_equal "Original Title", @task.title
    assert_equal "Original Description", @task.description
    assert_equal "high", @task.priority
    assert @task.completed?
  end

  # ==========================================================================
  # JSON Response Structure Validation
  # ==========================================================================

  test "API success response has correct JSON structure" do
    sign_out
    @task.update!(status: :pending_review)

    patch task_approval_path(@task),
          headers: api_headers(@creator_role),
          as: :json

    json = response.parsed_body

    # Validate required fields
    assert_equal "ok", json["status"]
    assert_equal @task.id, json["task_id"]
    assert_equal @task.assignee_id, json["assignee_id"]
    assert_includes json["message"], "approved"

    # Validate no unexpected fields
    expected_keys = %w[status task_id assignee_id message]
    assert_equal expected_keys.sort, json.keys.sort
  end

  test "API error response has correct JSON structure" do
    sign_out
    @task.update!(status: :open)  # Invalid status

    patch task_approval_path(@task),
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
