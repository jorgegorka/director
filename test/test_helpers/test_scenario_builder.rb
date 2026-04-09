module TestScenarioBuilder
  # Comprehensive test scenario setup for MVP components

  # Authentication scenario builders
  class AuthenticationScenario
    attr_reader :users, :projects, :sessions

    def initialize
      @users = {}
      @projects = {}
      @sessions = {}
    end

    def with_admin_user(project_key = :acme)
      project = projects(project_key)
      user = users(:admin_user)
      @users[:admin] = user
      @projects[:main] = project

      Current.project = project
      @sessions[:admin] = user.sessions.create!(
        ip_address: "192.168.1.100",
        user_agent: "Test Browser Admin"
      )

      self
    end

    def with_regular_user(project_key = :acme)
      project = projects(project_key)
      user = users(:regular_user)
      @users[:regular] = user
      @projects[:main] ||= project

      Current.project = project
      @sessions[:regular] = user.sessions.create!(
        ip_address: "192.168.1.101",
        user_agent: "Test Browser Regular"
      )

      self
    end

    def with_cross_project_user
      project = projects(:widgets)
      user = users(:widgets_user)
      @users[:cross_project] = user
      @projects[:other] = project

      Current.project = project
      @sessions[:cross_project] = user.sessions.create!(
        ip_address: "192.168.1.102",
        user_agent: "Test Browser Cross Project"
      )

      self
    end

    def with_api_user(project_key = :acme)
      project = projects(project_key)
      user = users(:api_user)
      @users[:api] = user
      @projects[:api] = project

      Current.project = project
      @sessions[:api] = user.sessions.create!(
        ip_address: "10.0.0.1",
        user_agent: "API Client/1.0"
      )

      self
    end

    def setup_multi_tenant_isolation
      with_admin_user(:acme)
      with_cross_project_user

      # Ensure clean project context separation
      @isolation_data = {
        acme_project: projects(:acme),
        widgets_project: projects(:widgets),
        acme_user: @users[:admin],
        widgets_user: @users[:cross_project]
      }

      self
    end

    def isolation_data
      @isolation_data || {}
    end

    def cleanup
      @sessions.values.each(&:destroy!)
      Current.reset
    end
  end

  # API testing scenario builders
  class ApiScenario
    attr_reader :endpoints, :test_data, :headers

    def initialize
      @endpoints = {}
      @test_data = {}
      @headers = {}
    end

    def with_authenticated_endpoints(user, project = nil)
      project ||= projects(:acme)
      Current.project = project

      @headers[:authenticated] = {
        "Authorization" => "Bearer #{user.api_token}",
        "Content-Type" => "application/json"
      }

      @test_data[:auth_user] = user
      @test_data[:auth_project] = project

      self
    end

    def with_crud_endpoints(resource_name)
      base_path = "/api/#{resource_name}"

      @endpoints[:index] = "#{base_path}"
      @endpoints[:show] = "#{base_path}/:id"
      @endpoints[:create] = "#{base_path}"
      @endpoints[:update] = "#{base_path}/:id"
      @endpoints[:destroy] = "#{base_path}/:id"

      self
    end

    def with_test_data(key, value)
      @test_data[key] = value
      self
    end

    def endpoint_for(action, id: nil)
      path = @endpoints[action]
      return nil unless path

      id ? path.sub(":id", id.to_s) : path
    end

    def cleanup
      Current.reset
    end
  end

  # Database state scenario builders
  class DatabaseScenario
    def self.clean_slate
      # Preserve fixtures but clean dynamic data
      Session.delete_all
      AuditEvent.delete_all
      Notification.delete_all
    end

    def self.with_realistic_data
      # Create realistic test data scenarios
      admin = users(:admin_user)
      regular = users(:regular_user)
      project = projects(:acme)

      Current.project = project

      # Create some sessions
      3.times do |i|
        admin.sessions.create!(
          ip_address: "192.168.1.#{100 + i}",
          user_agent: "Browser Session #{i + 1}"
        )
      end

      2.times do |i|
        regular.sessions.create!(
          ip_address: "10.0.0.#{1 + i}",
          user_agent: "Mobile App #{i + 1}"
        )
      end
    end

    def self.with_rate_limit_data
      user = users(:rate_limit_test)
      project = projects(:acme)

      Current.project = project

      # Simulate rate limit scenario
      9.times do |i|
        user.sessions.create!(
          ip_address: "203.0.113.#{1 + i}",
          user_agent: "Rate Test #{i + 1}",
          created_at: 1.minute.ago + i.seconds
        )
      end
    end
  end

  # Helper methods for test classes
  def setup_auth_scenario
    AuthenticationScenario.new
  end

  def setup_api_scenario
    ApiScenario.new
  end

  def setup_database_scenario
    DatabaseScenario
  end

  # Quick scenario setups
  def setup_basic_auth_test
    setup_auth_scenario
      .with_admin_user
      .with_regular_user
  end

  def setup_multi_tenant_test
    setup_auth_scenario
      .setup_multi_tenant_isolation
  end

  def setup_api_auth_test
    setup_api_scenario
      .with_authenticated_endpoints(users(:api_user))
      .with_crud_endpoints("tasks")
  end

  def setup_comprehensive_test
    scenario = setup_auth_scenario
      .with_admin_user
      .with_regular_user
      .with_api_user
      .with_cross_project_user

    DatabaseScenario.with_realistic_data
    scenario
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include TestScenarioBuilder
end
