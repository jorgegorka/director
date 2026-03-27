require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
  end

  # --- Index ---

  test "should get index" do
    get agents_url
    assert_response :success
    assert_select ".agent-card", minimum: 3
  end

  test "should only show agents for current company" do
    get agents_url
    assert_response :success
    assert_select ".agent-card__name", text: "Claude Assistant"
    assert_select ".agent-card__name", text: "Widget Bot", count: 0
  end

  # --- Show ---

  test "should show agent" do
    get agent_url(@claude_agent)
    assert_response :success
    assert_select "h1", "Claude Assistant"
  end

  test "should show adapter type on detail page" do
    get agent_url(@http_agent)
    assert_response :success
    assert_select ".agent-detail__adapter-label", text: "HTTP API"
  end

  test "should not show agent from another company" do
    get agent_url(agents(:widgets_agent))
    assert_response :not_found
  end

  # --- New / Create ---

  test "should get new agent form" do
    get new_agent_url
    assert_response :success
    assert_select "form"
  end

  test "should create http agent" do
    assert_difference("Agent.count", 1) do
      post agents_url, params: {
        agent: {
          name: "New HTTP Agent",
          adapter_type: "http",
          adapter_config: { url: "https://example.com/api", method: "POST" }
        }
      }
    end
    agent = Agent.order(:created_at).last
    assert_equal "New HTTP Agent", agent.name
    assert agent.http?
    assert_equal "https://example.com/api", agent.adapter_config["url"]
    assert_equal @company, agent.company
    assert_redirected_to agent_url(agent)
  end

  test "should create process agent" do
    assert_difference("Agent.count", 1) do
      post agents_url, params: {
        agent: {
          name: "Script Agent",
          adapter_type: "process",
          adapter_config: { command: "/bin/test-agent.sh" }
        }
      }
    end
    agent = Agent.order(:created_at).last
    assert agent.process?
    assert_equal "/bin/test-agent.sh", agent.adapter_config["command"]
  end

  test "should create claude_local agent" do
    assert_difference("Agent.count", 1) do
      post agents_url, params: {
        agent: {
          name: "Local Claude",
          adapter_type: "claude_local",
          adapter_config: { model: "claude-sonnet-4-20250514" }
        }
      }
    end
    agent = Agent.order(:created_at).last
    assert agent.claude_local?
    assert_equal "claude-sonnet-4-20250514", agent.adapter_config["model"]
  end

  test "should not create agent with blank name" do
    assert_no_difference("Agent.count") do
      post agents_url, params: {
        agent: { name: "", adapter_type: "http", adapter_config: { url: "https://example.com" } }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create agent with duplicate name" do
    assert_no_difference("Agent.count") do
      post agents_url, params: {
        agent: {
          name: "Claude Assistant",
          adapter_type: "claude_local",
          adapter_config: { model: "claude-sonnet-4-20250514" }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create http agent without url" do
    assert_no_difference("Agent.count") do
      post agents_url, params: {
        agent: {
          name: "Broken HTTP Agent",
          adapter_type: "http",
          adapter_config: {}
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_agent_url(@claude_agent)
    assert_response :success
    assert_select "form"
  end

  test "should update agent" do
    patch agent_url(@claude_agent), params: {
      agent: { name: "Claude Assistant Pro", description: "Updated description" }
    }
    assert_redirected_to agent_url(@claude_agent)
    @claude_agent.reload
    assert_equal "Claude Assistant Pro", @claude_agent.name
    assert_equal "Updated description", @claude_agent.description
  end

  test "should update adapter config" do
    patch agent_url(@http_agent), params: {
      agent: {
        adapter_type: "http",
        adapter_config: { url: "https://new-endpoint.example.com/agent", method: "PUT" }
      }
    }
    assert_redirected_to agent_url(@http_agent)
    @http_agent.reload
    assert_equal "https://new-endpoint.example.com/agent", @http_agent.adapter_config["url"]
    assert_equal "PUT", @http_agent.adapter_config["method"]
  end

  test "should not update with blank name" do
    patch agent_url(@claude_agent), params: { agent: { name: "" } }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy agent" do
    assert_difference("Agent.count", -1) do
      delete agent_url(@http_agent)
    end
    assert_redirected_to agents_url
  end

  test "should nullify roles on destroy" do
    role = roles(:cto)
    assert_equal @claude_agent.id, role.agent_id

    delete agent_url(@claude_agent)

    role.reload
    assert_nil role.agent_id
  end

  # --- Auth / Scoping ---

  test "should redirect unauthenticated user" do
    sign_out
    get agents_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(
      email_address: "agentless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get agents_url
    assert_redirected_to new_company_url
  end

  # --- Heartbeat Schedule ---

  test "should create agent with heartbeat schedule" do
    assert_difference("Agent.count", 1) do
      post agents_url, params: {
        agent: {
          name: "Scheduled Agent",
          adapter_type: "http",
          adapter_config: { url: "https://example.com/agent" },
          heartbeat_enabled: "1",
          heartbeat_interval: "15"
        }
      }
    end
    agent = Agent.order(:created_at).last
    assert agent.heartbeat_enabled?
    assert_equal 15, agent.heartbeat_interval
  end

  test "should update agent heartbeat schedule" do
    patch agent_url(@claude_agent), params: {
      agent: {
        heartbeat_enabled: "1",
        heartbeat_interval: "30"
      }
    }
    assert_redirected_to agent_url(@claude_agent)
    @claude_agent.reload
    assert @claude_agent.heartbeat_enabled?
    assert_equal 30, @claude_agent.heartbeat_interval
  end

  test "should disable agent heartbeat" do
    @claude_agent.update_columns(heartbeat_enabled: true, heartbeat_interval: 15)
    patch agent_url(@claude_agent), params: {
      agent: { heartbeat_enabled: "0" }
    }
    assert_redirected_to agent_url(@claude_agent)
    @claude_agent.reload
    assert_not @claude_agent.heartbeat_enabled?
  end

  test "should show heartbeat section on agent detail page" do
    get agent_url(@claude_agent)
    assert_response :success
    assert_select ".agent-detail__heartbeat-config"
  end

  test "should show heartbeat events on agent detail page" do
    get agent_url(@claude_agent)
    assert_response :success
    # claude_agent has heartbeat events from fixtures
    assert_select ".heartbeat-table"
  end

  test "should link to heartbeat history from agent page" do
    get agent_url(@claude_agent)
    assert_response :success
    assert_select "a[href=?]", agent_heartbeats_path(@claude_agent)
  end
end
