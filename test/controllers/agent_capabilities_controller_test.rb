require "test_helper"

class AgentCapabilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @claude_agent = agents(:claude_agent)
    @widgets_agent = agents(:widgets_agent)
  end

  # --- Create ---

  test "should add capability to agent" do
    assert_difference("AgentCapability.count", 1) do
      post agent_capabilities_url(@claude_agent), params: {
        agent_capability: { name: "research", description: "Research and summarize topics" }
      }
    end
    assert_redirected_to agent_url(@claude_agent)
    assert_equal "Capability 'research' added.", flash[:notice]
  end

  test "should add capability with name only (no description)" do
    assert_difference("AgentCapability.count", 1) do
      post agent_capabilities_url(@claude_agent), params: {
        agent_capability: { name: "summarization" }
      }
    end
    assert_redirected_to agent_url(@claude_agent)
  end

  # --- Destroy ---

  test "should remove capability from agent" do
    cap = agent_capabilities(:claude_coding)
    assert_difference("AgentCapability.count", -1) do
      delete agent_capability_url(@claude_agent, cap)
    end
    assert_redirected_to agent_url(@claude_agent)
    assert_equal "Capability 'coding' removed.", flash[:notice]
  end

  # --- Validation ---

  test "should not add duplicate capability" do
    assert_no_difference("AgentCapability.count") do
      post agent_capabilities_url(@claude_agent), params: {
        agent_capability: { name: "coding" }
      }
    end
    assert_redirected_to agent_url(@claude_agent)
    assert flash[:alert].present?
  end

  test "should not add blank capability" do
    assert_no_difference("AgentCapability.count") do
      post agent_capabilities_url(@claude_agent), params: {
        agent_capability: { name: "" }
      }
    end
    assert_redirected_to agent_url(@claude_agent)
    assert flash[:alert].present?
  end

  # --- Scoping ---

  test "should not manage capabilities for agent in other company" do
    assert_no_difference("AgentCapability.count") do
      post agent_capabilities_url(@widgets_agent), params: {
        agent_capability: { name: "research" }
      }
    end
    assert_response :not_found
  end

  test "should not remove capability from agent in other company" do
    cap = agent_capabilities(:http_data_processing)
    # Attempting to delete via widgets_agent (other company) should 404
    assert_no_difference("AgentCapability.count") do
      delete agent_capability_url(@widgets_agent, cap)
    end
    assert_response :not_found
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    post agent_capabilities_url(@claude_agent), params: {
      agent_capability: { name: "research" }
    }
    assert_redirected_to new_session_url
  end
end
