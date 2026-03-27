require "test_helper"

class AgentTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @process_agent = agents(:process_agent)
  end

  # --- Validations ---

  test "valid with name, company, adapter_type, and valid adapter_config" do
    agent = Agent.new(
      name: "New Agent",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert agent.valid?
  end

  test "invalid without name" do
    agent = Agent.new(name: nil, company: @company, adapter_type: :http, adapter_config: { "url" => "https://example.com" })
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
  end

  test "invalid with duplicate name in same company" do
    agent = Agent.new(name: "Claude Assistant", company: @company, adapter_type: :http, adapter_config: { "url" => "https://example.com" })
    assert_not agent.valid?
    assert_includes agent.errors[:name], "already exists in this company"
  end

  test "allows same name in different company" do
    agent = Agent.new(
      name: "Claude Assistant",
      company: companies(:widgets),
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert agent.valid?
  end

  test "invalid when http agent missing url in adapter_config" do
    agent = Agent.new(
      name: "Bad HTTP",
      company: @company,
      adapter_type: :http,
      adapter_config: { "method" => "POST" }
    )
    assert_not agent.valid?
    assert_match /missing required keys: url/, agent.errors[:adapter_config].join
  end

  test "invalid when process agent missing command in adapter_config" do
    agent = Agent.new(
      name: "Bad Process",
      company: @company,
      adapter_type: :process,
      adapter_config: { "timeout" => 30 }
    )
    assert_not agent.valid?
    assert_match /missing required keys: command/, agent.errors[:adapter_config].join
  end

  test "invalid when claude_local agent missing model in adapter_config" do
    agent = Agent.new(
      name: "Bad Claude",
      company: @company,
      adapter_type: :claude_local,
      adapter_config: { "max_turns" => 5 }
    )
    assert_not agent.valid?
    assert_match /missing required keys: model/, agent.errors[:adapter_config].join
  end

  test "valid adapter_config with only required keys" do
    agent = Agent.new(
      name: "Minimal Claude",
      company: @company,
      adapter_type: :claude_local,
      adapter_config: { "model" => "claude-opus-4" }
    )
    assert agent.valid?
  end

  # --- Enums ---

  test "adapter_type enum: http?" do
    assert @http_agent.http?
    assert_not @claude_agent.http?
  end

  test "adapter_type enum: process?" do
    assert @process_agent.process?
  end

  test "adapter_type enum: claude_local?" do
    assert @claude_agent.claude_local?
  end

  test "status enum: idle?" do
    assert @claude_agent.idle?
  end

  test "status enum: paused?" do
    assert @process_agent.paused?
  end

  test "status enum covers all values" do
    %i[idle running paused error terminated pending_approval].each do |s|
      agent = Agent.new(status: s)
      assert agent.send(:"#{s}?"), "Expected #{s}? to return true"
    end
  end

  # --- Associations ---

  test "belongs to company via Tenantable" do
    assert_equal @company, @claude_agent.company
  end

  test "has many agent_capabilities" do
    capabilities = @claude_agent.agent_capabilities
    assert_equal 2, capabilities.count
  end

  test "has many roles" do
    assert_includes @claude_agent.roles, roles(:cto)
  end

  # --- Scoping ---

  test "for_current_company returns only agents in Current.company" do
    Current.company = @company
    agents = Agent.for_current_company
    assert_includes agents, @claude_agent
    assert_includes agents, @http_agent
    assert_not_includes agents, agents(:widgets_agent)
  ensure
    Current.company = nil
  end

  test "active scope excludes terminated agents" do
    terminated = Agent.new(
      name: "Dead Agent",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" },
      status: :terminated
    )
    terminated.save!

    active_agents = Agent.active
    assert_not_includes active_agents, terminated
    assert_includes active_agents, @claude_agent
  end

  # --- Methods ---

  test "online? returns true for idle agent" do
    assert @claude_agent.online?
  end

  test "online? returns true for running agent" do
    @claude_agent.status = :running
    assert @claude_agent.online?
  end

  test "offline? returns true for paused agent" do
    assert @process_agent.offline?
  end

  test "offline? returns true for error status" do
    @claude_agent.status = :error
    assert @claude_agent.offline?
  end

  test "offline? returns true for terminated status" do
    @claude_agent.status = :terminated
    assert @claude_agent.offline?
  end

  test "offline? returns true for pending_approval status" do
    @claude_agent.status = :pending_approval
    assert @claude_agent.offline?
  end

  test "adapter returns correct adapter class for claude_local" do
    assert_equal ClaudeLocalAdapter, @claude_agent.adapter_class
  end

  test "adapter returns correct adapter class for http" do
    assert_equal HttpAdapter, @http_agent.adapter_class
  end

  test "adapter returns correct adapter class for process" do
    assert_equal ProcessAdapter, @process_agent.adapter_class
  end

  # --- Deletion behavior ---

  test "destroying agent nullifies roles.agent_id" do
    cto = roles(:cto)
    assert_equal @claude_agent.id, cto.agent_id
    @claude_agent.destroy
    cto.reload
    assert_nil cto.agent_id
  end

  test "destroying agent destroys its capabilities" do
    cap_count = @claude_agent.agent_capabilities.count
    assert cap_count > 0
    assert_difference "AgentCapability.count", -cap_count do
      @claude_agent.destroy
    end
  end

  test "destroying company destroys all its agents" do
    agent_count = @company.agents.count
    assert agent_count > 0
    assert_difference "Agent.count", -agent_count do
      @company.destroy
    end
  end
end
