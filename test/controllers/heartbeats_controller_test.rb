require "test_helper"

class HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
  end

  # --- Index ---

  test "should get index for agent with heartbeat events" do
    get agent_heartbeats_url(@claude_agent)
    assert_response :success
    assert_select "h1", "Heartbeat History"
    assert_select ".heartbeat-table"
  end

  test "should show empty state for agent without events" do
    agent = Agent.create!(
      name: "Empty Agent",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    get agent_heartbeats_url(agent)
    assert_response :success
    assert_select ".heartbeats-history__empty"
  end

  test "should show trigger type badges" do
    get agent_heartbeats_url(@claude_agent)
    assert_response :success
    assert_select ".heartbeat-badge"
  end

  test "should show status indicators" do
    get agent_heartbeats_url(@claude_agent)
    assert_response :success
    assert_select ".heartbeat-status"
  end

  test "should show total event count" do
    get agent_heartbeats_url(@claude_agent)
    assert_response :success
    assert_select ".heartbeats-history__subtitle", /total events/
  end

  test "should link back to agent" do
    get agent_heartbeats_url(@claude_agent)
    assert_response :success
    assert_select "a[href=?]", agent_path(@claude_agent)
  end

  test "should not show heartbeats for agent from another company" do
    widgets_agent = agents(:widgets_agent)
    get agent_heartbeats_url(widgets_agent)
    assert_response :not_found
  end

  test "should redirect unauthenticated user" do
    sign_out
    get agent_heartbeats_url(@claude_agent)
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(
      email_address: "heartbeatless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get agent_heartbeats_url(@claude_agent)
    assert_redirected_to new_company_url
  end

  # --- Pagination ---

  test "should handle page parameter" do
    get agent_heartbeats_url(@claude_agent, page: 1)
    assert_response :success
  end

  test "should handle invalid page gracefully" do
    get agent_heartbeats_url(@claude_agent, page: -1)
    assert_response :success
  end
end
