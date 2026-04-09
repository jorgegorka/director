module EnhancedAuthTestHelper
  # Enhanced authentication test patterns for MVP components

  # Creates a user session with project context for multi-tenancy testing
  def sign_in_with_project(user, project = nil)
    project ||= projects(:acme) # Default to acme project
    Current.project = project
    sign_in_as(user)
  end

  # Creates an authenticated session for API testing with project scoping
  def authenticated_api_session(user, project = nil)
    project ||= projects(:acme)
    Current.project = project
    Current.session = user.sessions.create!
    { "Authorization" => "Bearer #{user.api_token}" }
  end

  # Simulates rate limiting scenarios for authentication endpoints
  def simulate_rate_limit_attempts(endpoint, user, attempts = 10)
    attempts.times do |i|
      post endpoint, params: {
        email_address: user.email_address,
        password: "wrong_password_#{i}"
      }
    end
  end

  # Creates test data for complex authentication scenarios
  def setup_multi_project_auth_scenario
    @user1 = users(:one)
    @user2 = users(:two)
    @project1 = projects(:acme)
    @project2 = projects(:widgets)

    # Create sessions for different projects
    Current.project = @project1
    @session1 = @user1.sessions.create!

    Current.project = @project2
    @session2 = @user2.sessions.create!

    { user1: @user1, user2: @user2, project1: @project1, project2: @project2 }
  end

  # Validates session security attributes
  def assert_secure_session_attributes(session)
    assert session.persisted?, "Session should be persisted"
    assert session.ip_address.present?, "Session should track IP address"
    assert session.user_agent.present?, "Session should track user agent"
    assert session.created_at.present?, "Session should have creation timestamp"
  end

  # Tests cross-project access prevention
  def assert_cross_project_isolation(user, other_project_resource_path)
    original_project = Current.project

    # Switch to different project context
    Current.project = projects(:widgets) if Current.project == projects(:acme)
    Current.project = projects(:acme) if Current.project == projects(:widgets)

    get other_project_resource_path
    assert_response :not_found, "Should not access resources from different project"

    # Restore original context
    Current.project = original_project
  end

  # Password security test patterns
  def assert_password_security_requirements(user)
    # Test password hashing
    assert user.password_digest.present?, "Password should be hashed"
    assert user.password_digest.starts_with?("$2a$"), "Should use bcrypt hashing"

    # Test password authentication
    assert user.authenticate("password"), "Should authenticate with correct password"
    assert_not user.authenticate("wrong"), "Should not authenticate with wrong password"
  end

  # Email normalization test patterns
  def assert_email_normalization(test_cases)
    test_cases.each do |input, expected|
      user = User.new(email_address: input)
      assert_equal expected, user.email_address,
        "Email '#{input}' should normalize to '#{expected}'"
    end
  end

  # Session cleanup test patterns
  def assert_session_cleanup_on_password_change(user)
    old_sessions = user.sessions.to_a
    user.update!(password: "new_secure_password")

    old_sessions.each do |session|
      assert_not Session.exists?(session.id),
        "Old session #{session.id} should be destroyed after password change"
    end
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include EnhancedAuthTestHelper
end