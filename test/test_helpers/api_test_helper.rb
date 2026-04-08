module ApiTestHelper
  def api_headers(role)
    { "Authorization" => "Bearer #{role.api_token}" }
  end

  def invalid_api_headers
    { "Authorization" => "Bearer invalid_token_xyz" }
  end

  def cross_project_role
    roles(:widgets_lead)
  end

  # Asserts that a cross-project role gets a 404 when accessing a resource
  def assert_prevents_cross_project_access(method, path)
    sign_out
    send(method, path, headers: api_headers(cross_project_role), as: :json)

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end

  # Asserts that unauthenticated session requests redirect to login
  def assert_requires_authentication(method, path)
    send(method, path)
    assert_redirected_to new_session_url
  end

  # Asserts that JSON requests without a Bearer token get 401
  def assert_api_requires_bearer_token(method, path)
    send(method, path, as: :json)
    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  # Asserts that JSON requests with an invalid Bearer token get 401
  def assert_api_rejects_invalid_token(method, path)
    send(method, path, headers: invalid_api_headers, as: :json)
    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Unauthorized", json["error"]
  end

  # Validates a successful API response JSON structure
  def assert_api_success_response(expected_task_id:, expected_assignee_id:, message_pattern:)
    assert_response :ok
    json = response.parsed_body

    assert_equal "ok", json["status"]
    assert_equal expected_task_id, json["task_id"]
    assert_equal expected_assignee_id, json["assignee_id"]
    assert_includes json["message"], message_pattern

    expected_keys = %w[status task_id assignee_id message]
    assert_equal expected_keys.sort, json.keys.sort
  end

  # Validates an error API response JSON structure
  def assert_api_error_response(message)
    assert_response :unprocessable_entity
    json = response.parsed_body

    assert json.key?("error")
    assert_includes json["error"], message
  end

  # Finds and returns the latest audit event matching the given criteria
  def assert_audit_event_created(action:, actor:)
    event = AuditEvent.where(action: action).order(:created_at).last
    assert event, "Expected an AuditEvent with action '#{action}' to exist"
    assert_equal actor.class.name, event.actor_type
    assert_equal actor.id, event.actor_id
    event
  end

  # Asserts that a request to a nonexistent resource returns 404
  def assert_handles_missing_resource(method, path_template)
    path = path_template.sub(":id", "999999")
    role = roles(:cto)

    send(method, path, headers: api_headers(role), as: :json)
    assert_response :not_found
    json = response.parsed_body
    assert_equal "Not found", json["error"]
  end

  # Asserts that malformed JSON is handled gracefully
  def assert_handles_malformed_json(method, path, headers:)
    send(method, path,
         params: '{"malformed": json}',
         headers: headers.merge("CONTENT_TYPE" => "application/json"))

    assert_includes [ 400, 422 ], response.status
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ApiTestHelper
end
