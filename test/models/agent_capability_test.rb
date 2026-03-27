require "test_helper"

class AgentCapabilityTest < ActiveSupport::TestCase
  setup do
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @coding_cap = agent_capabilities(:claude_coding)
    @analysis_cap = agent_capabilities(:claude_analysis)
  end

  # --- Validations ---

  test "valid with name and agent" do
    cap = AgentCapability.new(name: "reporting", agent: @claude_agent)
    assert cap.valid?
  end

  test "invalid without name" do
    cap = AgentCapability.new(name: nil, agent: @claude_agent)
    assert_not cap.valid?
    assert_includes cap.errors[:name], "can't be blank"
  end

  test "invalid with duplicate name on same agent" do
    cap = AgentCapability.new(name: "coding", agent: @claude_agent)
    assert_not cap.valid?
    assert_includes cap.errors[:name], "already declared for this agent"
  end

  test "allows same capability name on different agent" do
    cap = AgentCapability.new(name: "coding", agent: @http_agent)
    assert cap.valid?
  end

  # --- Associations ---

  test "belongs to agent" do
    assert_equal @claude_agent, @coding_cap.agent
  end

  # --- Scopes ---

  test "by_name scope returns capabilities ordered alphabetically" do
    caps = @claude_agent.agent_capabilities.by_name.map(&:name)
    assert_equal caps.sort, caps
  end

  test "by_name returns analysis before coding" do
    names = @claude_agent.agent_capabilities.by_name.map(&:name)
    assert_equal [ "analysis", "coding" ], names
  end
end
