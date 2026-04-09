ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Load all test helpers
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/api_test_helper"
require_relative "test_helpers/enhanced_auth_test_helper"
require_relative "test_helpers/enhanced_api_test_helper"
require_relative "test_helpers/test_scenario_builder"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Ensure clean test environment
    setup do
      # Reset Current attributes for clean test state
      Current.reset

      # WebMock reset for clean HTTP state
      WebMock.reset!
    end

    teardown do
      # Clean up Current state after each test
      Current.reset
    end

    # Add more helper methods to be used by all tests here...
  end
end
