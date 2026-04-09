# Rails 8 Testing Infrastructure Setup Guide

This guide documents the comprehensive testing framework for MVP authentication and API components using Rails 8 + Minitest + fixtures.

## Overview

Our testing infrastructure provides:
- **Enhanced authentication testing patterns** for multi-tenant auth flows
- **Comprehensive API testing utilities** with project isolation
- **Realistic fixture data** for complex scenarios
- **Test scenario builders** for quick setup
- **Example patterns** following Rails 8 best practices

## Quick Start

### 1. Basic Authentication Test

```ruby
require "test_helper"

class MyControllerTest < ActionDispatch::IntegrationTest
  test "protected action requires authentication" do
    get "/protected_resource"
    assert_requires_authentication(:get, "/protected_resource")
  end

  test "authenticated user can access resource" do
    user = users(:regular_user)
    project = projects(:acme)
    
    sign_in_with_project(user, project)
    get "/protected_resource"
    
    assert_response :success
  end
end
```

### 2. Basic API Test

```ruby
require "test_helper"

class MyApiTest < ActionDispatch::IntegrationTest
  test "API endpoint with authentication" do
    user = users(:api_user)
    project = projects(:acme)
    
    # Test unauthenticated request
    api_get "/api/tasks"
    assert_response :unauthorized
    
    # Test authenticated request
    api_get "/api/tasks", user: user, project: project
    assert_response :success
    
    assert_api_response_structure(
      expected_status: :ok,
      required_fields: %w[data meta]
    )
  end
end
```

### 3. Basic Model Test

```ruby
require "test_helper"

class MyModelTest < ActiveSupport::TestCase
  test "model validation and security" do
    user = User.new(
      email_address: "test@example.com",
      password: "SecurePass123!"
    )
    
    assert user.valid?
    assert_password_security_requirements(user)
  end
end
```

## Available Test Helpers

### Authentication Helpers (`EnhancedAuthTestHelper`)

```ruby
# Sign in with project context
sign_in_with_project(user, project)

# Create authenticated API session
authenticated_api_session(user, project)

# Test rate limiting
simulate_rate_limit_attempts(endpoint, user, attempts)

# Setup multi-tenant scenarios
setup_multi_project_auth_scenario

# Validate session security
assert_secure_session_attributes(session)

# Test cross-project isolation
assert_cross_project_isolation(user, other_project_path)

# Test password security
assert_password_security_requirements(user)

# Test email normalization
assert_email_normalization(test_cases)

# Test session cleanup
assert_session_cleanup_on_password_change(user)
```

### API Helpers (`EnhancedApiTestHelper`)

```ruby
# API request methods with authentication
api_get(path, user: nil, project: nil, headers: {})
api_post(path, params: {}, user: nil, project: nil, headers: {})
api_patch(path, params: {}, user: nil, project: nil, headers: {})
api_delete(path, user: nil, project: nil, headers: {})

# Response validation
assert_api_response_structure(expected_status:, required_fields:, optional_fields:)
assert_api_pagination(response_json, expected_total:, expected_per_page:)
assert_api_validation_error(field:, message_pattern:)

# Security testing
assert_api_rate_limiting(endpoint, headers:, limit:)
assert_api_project_isolation(resource_path, user:, target_project:, other_project:)

# Bulk operations
assert_bulk_api_operation(endpoint, operations:, user:, project:)

# Authentication scenarios
test_api_authentication_scenarios(endpoint, method:, params:)
```

### Scenario Builders (`TestScenarioBuilder`)

```ruby
# Authentication scenarios
scenario = setup_auth_scenario
  .with_admin_user
  .with_regular_user
  .with_api_user
  .with_cross_project_user

# API scenarios
api_scenario = setup_api_scenario
  .with_authenticated_endpoints(user, project)
  .with_crud_endpoints("tasks")
  .with_test_data(:key, value)

# Database scenarios
setup_database_scenario.clean_slate
setup_database_scenario.with_realistic_data
setup_database_scenario.with_rate_limit_data

# Quick setups
setup_basic_auth_test
setup_multi_tenant_test
setup_api_auth_test
setup_comprehensive_test
```

## Fixture Data

### Users (`test/fixtures/enhanced_users.yml`)

```yaml
admin_user:
  email_address: admin@acme.example.com
  password_digest: <%= bcrypt_digest %>

regular_user:
  email_address: user@acme.example.com
  password_digest: <%= bcrypt_digest %>

api_user:
  email_address: api@acme.example.com
  password_digest: <%= bcrypt_digest %>

# Cross-project users
widgets_admin:
  email_address: admin@widgets.example.com
  password_digest: <%= bcrypt_digest %>

# Specialized test users
weak_password_user:
rate_limit_test:
uppercase_email:
whitespace_email:
```

### Projects

```yaml
acme:
  name: Acme AI Corp

widgets:
  name: Widget Factory
```

## Test Structure Examples

### Controller Test Structure

```ruby
class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  # Test basic flows
  test "login flow"
  test "logout flow"
  test "registration flow"
  
  # Test security
  test "rate limiting"
  test "session security"
  test "password requirements"
  
  # Test multi-tenancy
  test "project isolation"
  test "cross-project access prevention"
  
  # Test edge cases
  test "invalid credentials"
  test "malformed requests"
  test "missing parameters"
end
```

### API Test Structure

```ruby
class ApiControllerTest < ActionDispatch::IntegrationTest
  # Test authentication
  test "requires authentication"
  test "handles invalid tokens"
  test "respects project boundaries"
  
  # Test CRUD operations
  test "create resource"
  test "read resource"
  test "update resource"
  test "delete resource"
  
  # Test validation
  test "validates input"
  test "handles validation errors"
  
  # Test pagination and filtering
  test "paginates results"
  test "filters by parameters"
  
  # Test security
  test "rate limiting"
  test "input sanitization"
  test "output serialization"
end
```

### Model Test Structure

```ruby
class UserTest < ActiveSupport::TestCase
  # Test validations
  test "validates required fields"
  test "validates format constraints"
  test "validates uniqueness constraints"
  
  # Test callbacks
  test "before_save normalization"
  test "after_create initialization"
  
  # Test associations
  test "has_many relationships"
  test "dependent destroy behavior"
  
  # Test methods
  test "instance methods"
  test "class methods"
  test "scope methods"
  
  # Test security
  test "password hashing"
  test "authentication methods"
  test "sensitive data protection"
end
```

## Running Tests

### All Tests
```bash
bin/rails test
```

### Specific Test Types
```bash
bin/rails test test/controllers/
bin/rails test test/models/
bin/rails test test/examples/
```

### Single Test File
```bash
bin/rails test test/examples/authentication_controller_patterns_test.rb
```

### Single Test Method
```bash
bin/rails test test/examples/authentication_controller_patterns_test.rb:25
```

### With Coverage (if configured)
```bash
COVERAGE=true bin/rails test
```

## Best Practices

### 1. Use Fixture Data
- Prefer fixtures over factories for consistency
- Use realistic data that mirrors production scenarios
- Keep fixture data focused and minimal

### 2. Test Project Isolation
- Always test with proper project context
- Verify cross-project access is prevented
- Use multi-tenant test scenarios

### 3. Security First
- Test authentication and authorization thoroughly
- Validate input sanitization and output security
- Test rate limiting and abuse prevention

### 4. API Testing
- Test all HTTP methods and status codes
- Validate JSON response structures
- Test error handling and edge cases

### 5. Documentation
- Use descriptive test names
- Comment complex test scenarios
- Provide examples for other developers

## Troubleshooting

### Common Issues

**Tests failing due to project context:**
```ruby
# Always set project context in multi-tenant tests
setup do
  Current.project = projects(:acme)
end

teardown do
  Current.reset
end
```

**Session authentication not working:**
```ruby
# Use the helper methods instead of manual session setup
sign_in_with_project(user, project)
# instead of manual Current.session = ...
```

**API tests not finding resources:**
```ruby
# Ensure API tests use proper project scoping
api_get "/api/resource", user: user, project: project
# instead of manual header setup
```

### Performance Tips

- Use `parallelize(workers: :number_of_processors)` for faster test runs
- Clean up test data in teardown methods
- Use database transactions for test isolation
- Avoid creating unnecessary test data

## Integration with CI/CD

The testing infrastructure integrates with the standard Rails test commands used in CI:

```bash
# In CI pipeline
bin/ci  # Runs rubocop → security → tests
```

This ensures all tests pass with proper linting and security checks before deployment.