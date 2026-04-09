require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @task = tasks(:design_homepage)
    @widgets_task = tasks(:widgets_task)
    @first_update = messages(:first_update)
  end

  # --- Create ---

  test "should create message" do
    assert_difference("Message.count", 1) do
      post task_messages_url(@task), params: {
        message: { body: "This is a new message." }
      }
    end
    message = Message.order(:created_at).last
    assert_equal "This is a new message.", message.body
    assert_redirected_to task_url(@task, anchor: "message_#{message.id}")
  end

  test "message author is current user" do
    post task_messages_url(@task), params: {
      message: { body: "Authored message." }
    }
    message = Message.order(:created_at).last
    assert_equal @user, message.author
    assert_equal "User", message.author_type
    assert_equal @user.id, message.author_id
  end

  test "should create reply message" do
    assert_difference("Message.count", 1) do
      post task_messages_url(@task), params: {
        message: { body: "This is a reply.", parent_id: @first_update.id }
      }
    end
    reply = Message.order(:created_at).last
    assert_equal @first_update, reply.parent
    assert_equal @task, reply.task
  end

  test "should not create message with blank body" do
    assert_no_difference("Message.count") do
      post task_messages_url(@task), params: {
        message: { body: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create message on task from another project" do
    assert_no_difference("Message.count") do
      post task_messages_url(@widgets_task), params: {
        message: { body: "Cross-project message." }
      }
    end
    assert_redirected_to root_url
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    post task_messages_url(@task), params: {
      message: { body: "Unauthorized message." }
    }
    assert_redirected_to new_session_url
  end

  # ==========================================================================
  # Bearer Token Authentication Tests (API)
  # ==========================================================================

  test "role can create message via API with Bearer token" do
    sign_out
    assignee_role = @task.assignee

    assert_difference("Message.count", 1) do
      post task_messages_url(@task),
           params: { message: { body: "API message from role" } },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :created
    json = response.parsed_body

    # Validate JSON response structure
    assert_equal assignee_role.id, json["author"]["id"]
    assert_equal "Role", json["author"]["type"]
    assert_equal assignee_role.title, json["author"]["title"]
    assert_equal "API message from role", json["body"]
    assert_equal "comment", json["message_type"]
    assert json["id"].present?
    assert json["created_at"].present?

    # Validate message was created correctly
    message = Message.find(json["id"])
    assert_equal assignee_role, message.author
    assert_equal @task, message.task
    assert_equal "API message from role", message.body
  end

  test "role can create reply message via API" do
    sign_out
    assignee_role = @task.assignee

    assert_difference("Message.count", 1) do
      post task_messages_url(@task),
           params: {
             message: {
               body: "API reply message",
               parent_id: @first_update.id
             }
           },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :created
    json = response.parsed_body

    # Validate reply structure
    message = Message.find(json["id"])
    assert_equal @first_update, message.parent
    assert_equal @task, message.task
    assert_equal "API reply message", message.body
  end

  test "role can create question message via API" do
    sign_out
    assignee_role = @task.assignee

    assert_difference("Message.count", 1) do
      post task_messages_url(@task),
           params: {
             message: {
               body: "API question message",
               message_type: "question"
             }
           },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :created
    json = response.parsed_body

    assert_equal "question", json["message_type"]

    message = Message.find(json["id"])
    assert message.question?
  end

  test "API message creation requires Bearer token" do
    sign_out

    post task_messages_url(@task),
         params: { message: { body: "Unauthorized API message" } },
         as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "API message creation rejects invalid Bearer token" do
    sign_out

    post task_messages_url(@task),
         params: { message: { body: "Invalid token message" } },
         headers: invalid_api_headers,
         as: :json

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  test "API message creation prevents cross-project access" do
    sign_out
    cross_role = cross_project_role

    post task_messages_url(@task),
         params: { message: { body: "Cross-project message" } },
         headers: api_headers(cross_role),
         as: :json

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end

  # ==========================================================================
  # Authorization and Permission Tests
  # ==========================================================================

  test "API message creation allows task assignee" do
    sign_out
    assignee_role = @task.assignee

    post task_messages_url(@task),
         params: { message: { body: "Message from assignee" } },
         headers: api_headers(assignee_role),
         as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "Message from assignee", json["body"]
    assert_equal assignee_role.id, json["author"]["id"]
  end

  test "API message creation allows any role in same project" do
    sign_out
    other_role = roles(:developer) # Different role but same project

    post task_messages_url(@task),
         params: { message: { body: "Message from other role" } },
         headers: api_headers(other_role),
         as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "Message from other role", json["body"]
    assert_equal other_role.id, json["author"]["id"]
  end

  test "API message creation works with role that has api_token" do
    sign_out
    cmo_role = roles(:cmo) # Has API token and is in same project

    post task_messages_url(@task),
         params: { message: { body: "Message from CMO" } },
         headers: api_headers(cmo_role),
         as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "Message from CMO", json["body"]
    assert_equal cmo_role.id, json["author"]["id"]
  end

  # ==========================================================================
  # Validation and Error Handling Tests
  # ==========================================================================

  test "API returns validation error for blank message body" do
    sign_out
    assignee_role = @task.assignee

    assert_no_difference("Message.count") do
      post task_messages_url(@task),
           params: { message: { body: "" } },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
    assert_includes json["error"].downcase, "blank"
  end

  test "API returns validation error for missing message body" do
    sign_out
    assignee_role = @task.assignee

    assert_no_difference("Message.count") do
      post task_messages_url(@task),
           params: { message: {} },
           headers: api_headers(assignee_role),
           as: :json
    end

    # Can be either 400 (bad request) or 422 (unprocessable entity)
    assert_includes [ 400, 422 ], response.status
    json = response.parsed_body
    assert json["error"].present?
  end

  test "API handles invalid parent_id gracefully" do
    sign_out
    assignee_role = @task.assignee

    assert_no_difference("Message.count") do
      post task_messages_url(@task),
           params: {
             message: {
               body: "Reply to nonexistent message",
               parent_id: 999999
             }
           },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "API handles invalid message_type gracefully" do
    sign_out
    assignee_role = @task.assignee

    # Invalid message_type should cause validation error
    assert_no_difference("Message.count") do
      post task_messages_url(@task),
           params: {
             message: {
               body: "Message with invalid type",
               message_type: "invalid_type"
             }
           },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  # ==========================================================================
  # Error Handling and Edge Cases
  # ==========================================================================

  test "API handles missing task gracefully" do
    sign_out
    assignee_role = @task.assignee

    post "/tasks/999999/messages",
         params: { message: { body: "Message for missing task" } },
         headers: api_headers(assignee_role),
         as: :json

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end

  test "API handles malformed JSON gracefully" do
    sign_out
    assignee_role = @task.assignee

    # Send malformed JSON
    post task_messages_url(@task),
         params: '{"malformed": json}',
         headers: api_headers(assignee_role).merge("CONTENT_TYPE" => "application/json")

    # Should handle gracefully, not crash
    assert_includes [ 400, 422 ], response.status
  end

  # ==========================================================================
  # JSON Response Structure Validation
  # ==========================================================================

  test "API success response has correct JSON structure" do
    sign_out
    assignee_role = @task.assignee

    post task_messages_url(@task),
         params: { message: { body: "Test message for JSON validation" } },
         headers: api_headers(assignee_role),
         as: :json

    json = response.parsed_body

    # Validate required fields
    assert json["id"].is_a?(Integer)
    assert_equal "Test message for JSON validation", json["body"]
    assert_equal "comment", json["message_type"]
    assert json["created_at"].is_a?(String)

    # Validate author structure
    assert json["author"].is_a?(Hash)
    assert_equal assignee_role.id, json["author"]["id"]
    assert_equal assignee_role.title, json["author"]["title"]
    assert_equal "Role", json["author"]["type"]

    # Validate no unexpected fields at top level
    expected_keys = %w[id body message_type author created_at]
    assert_equal expected_keys.sort, json.keys.sort
  end

  test "API error response has correct JSON structure" do
    sign_out
    assignee_role = @task.assignee

    post task_messages_url(@task),
         params: { message: { body: "" } }, # Invalid blank body
         headers: api_headers(assignee_role),
         as: :json

    json = response.parsed_body

    # Validate error structure
    assert json.key?("error")
    assert json["error"].is_a?(String)

    # Should only have error field
    assert_equal [ "error" ], json.keys
  end

  # ==========================================================================
  # Boundary Condition Tests
  # ==========================================================================

  test "API handles very long message body" do
    sign_out
    assignee_role = @task.assignee
    long_body = "x" * 10000 # Very long message

    assert_difference("Message.count", 1) do
      post task_messages_url(@task),
           params: { message: { body: long_body } },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :created
    message = Message.last
    assert_equal long_body, message.body
  end

  test "API handles special characters in message body" do
    sign_out
    assignee_role = @task.assignee
    special_body = "Test with special chars: émojis 🚀, quotes \"'`, and symbols @#$%"

    assert_difference("Message.count", 1) do
      post task_messages_url(@task),
           params: { message: { body: special_body } },
           headers: api_headers(assignee_role),
           as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal special_body, json["body"]
  end

  test "API preserves existing task data when creating message" do
    sign_out
    assignee_role = @task.assignee
    original_title = @task.title
    original_status = @task.status

    post task_messages_url(@task),
         params: { message: { body: "Message should not affect task" } },
         headers: api_headers(assignee_role),
         as: :json

    @task.reload
    assert_equal original_title, @task.title
    assert_equal original_status, @task.status
  end
end
