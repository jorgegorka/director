module EnhancedApiTestHelper
  # Enhanced API testing patterns for MVP components

  # Comprehensive API request builders
  def api_get(path, user: nil, project: nil, headers: {})
    send_api_request(:get, path, user: user, project: project, headers: headers)
  end

  def api_post(path, params: {}, user: nil, project: nil, headers: {})
    send_api_request(:post, path, params: params, user: user, project: project, headers: headers)
  end

  def api_patch(path, params: {}, user: nil, project: nil, headers: {})
    send_api_request(:patch, path, params: params, user: user, project: project, headers: headers)
  end

  def api_delete(path, user: nil, project: nil, headers: {})
    send_api_request(:delete, path, user: user, project: project, headers: headers)
  end

  # Validates complete API response structure
  def assert_api_response_structure(expected_status:, required_fields: [], optional_fields: [])
    assert_response expected_status

    json = response.parsed_body
    assert json.is_a?(Hash), "Response should be JSON object"

    required_fields.each do |field|
      assert json.key?(field), "Response missing required field: #{field}"
    end

    # Ensure no unexpected fields (helps catch API leaks)
    expected_fields = (required_fields + optional_fields).map(&:to_s)
    unexpected = json.keys - expected_fields
    assert unexpected.empty?, "Response contains unexpected fields: #{unexpected}"
  end

  # Tests API pagination patterns
  def assert_api_pagination(response_json, expected_total: nil, expected_per_page: nil)
    pagination_fields = %w[current_page total_pages total_count per_page]

    pagination_fields.each do |field|
      assert response_json.key?(field), "Pagination missing field: #{field}"
    end

    assert response_json["total_count"] == expected_total if expected_total
    assert response_json["per_page"] == expected_per_page if expected_per_page
    assert response_json["current_page"] >= 1
    assert response_json["total_pages"] >= 1
  end

  # API error handling test patterns
  def assert_api_validation_error(field:, message_pattern:)
    assert_response :unprocessable_entity
    json = response.parsed_body

    assert json.key?("errors"), "Validation error response should include errors"
    assert json["errors"].key?(field), "Should have validation error for field: #{field}"
    assert_match message_pattern, json["errors"][field].first if message_pattern
  end

  # Rate limiting test patterns
  def assert_api_rate_limiting(endpoint, headers:, limit: 10)
    (limit + 1).times do |i|
      post endpoint, headers: headers, as: :json

      if i < limit
        assert_response :success, "Request #{i + 1} should succeed within rate limit"
      else
        assert_response :too_many_requests, "Request #{i + 1} should be rate limited"
      end
    end
  end

  # Project isolation test patterns
  def assert_api_project_isolation(resource_path, user:, target_project:, other_project:)
    # Setup: create resource in target project
    Current.project = target_project
    sign_in_as(user)

    # Test: try to access from different project context
    Current.project = other_project
    get resource_path, headers: api_headers(user), as: :json

    assert_response :not_found, "Should not access resource from different project context"
  end

  # API versioning test patterns (if needed for future)
  def api_request_with_version(method, path, version: "v1", **options)
    headers = options[:headers] || {}
    headers["Accept"] = "application/vnd.director.#{version}+json"

    send(method, path, **options.merge(headers: headers))
  end

  # Bulk API operation test patterns
  def assert_bulk_api_operation(endpoint, operations:, user:, project:)
    Current.project = project
    headers = api_headers(user)

    post endpoint,
         params: { operations: operations },
         headers: headers,
         as: :json

    assert_response :ok
    json = response.parsed_body

    assert json.key?("results"), "Bulk operation should return results array"
    assert_equal operations.size, json["results"].size, "Should process all operations"
  end

  # API authentication test patterns
  def assert_api_authentication_scenarios(endpoint, method: :get, params: {})
    scenarios = [
      { name: "no auth header", headers: {}, expected: :unauthorized },
      { name: "invalid token", headers: invalid_api_headers, expected: :unauthorized },
      { name: "expired token", headers: expired_api_headers, expected: :unauthorized },
      { name: "valid token", headers: api_headers(users(:one)), expected: :success }
    ]

    scenarios.each do |scenario|
      send(method, endpoint, params: params, headers: scenario[:headers], as: :json)
      assert_response scenario[:expected],
        "#{scenario[:name]} should return #{scenario[:expected]} for #{endpoint}"
    end
  end

  private

  def send_api_request(method, path, params: {}, user: nil, project: nil, headers: {})
    if user && project
      Current.project = project
      headers = api_headers(user).merge(headers)
    end

    request_options = { headers: headers, as: :json }
    request_options[:params] = params if [ :post, :patch, :put ].include?(method)

    send(method, path, **request_options)
  end

  def expired_api_headers
    # Simulate expired token (implementation would depend on token structure)
    { "Authorization" => "Bearer expired_token_xyz" }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include EnhancedApiTestHelper
end
