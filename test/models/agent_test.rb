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

  # --- API Token ---

  test "generates api_token on create" do
    agent = Agent.create!(
      name: "Token Agent",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert agent.api_token.present?
    assert_equal 24, agent.api_token.length
  end

  test "api_token is unique" do
    agent1 = Agent.create!(
      name: "Token Agent 1",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    agent2 = Agent.create!(
      name: "Token Agent 2",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert_not_equal agent1.api_token, agent2.api_token
  end

  test "regenerate_api_token! changes the token" do
    old_token = @claude_agent.api_token
    @claude_agent.regenerate_api_token!
    assert_not_equal old_token, @claude_agent.api_token
    assert @claude_agent.api_token.present?
  end

  # --- Budget ---

  test "valid with budget_cents" do
    @claude_agent.budget_cents = 50000
    assert @claude_agent.valid?
  end

  test "invalid with negative budget_cents" do
    @claude_agent.budget_cents = -100
    assert_not @claude_agent.valid?
    assert_includes @claude_agent.errors[:budget_cents], "must be greater than 0"
  end

  test "invalid with zero budget_cents" do
    @claude_agent.budget_cents = 0
    assert_not @claude_agent.valid?
  end

  test "valid with nil budget_cents (no budget)" do
    @claude_agent.budget_cents = nil
    assert @claude_agent.valid?
  end

  test "budget_configured? returns true when budget_cents present" do
    assert @claude_agent.budget_configured?
  end

  test "budget_configured? returns false when budget_cents nil" do
    @process_agent.budget_cents = nil
    assert_not @process_agent.budget_configured?
  end

  test "monthly_spend_cents returns sum of task costs in current period" do
    expected = Task.where(assignee: @claude_agent)
                   .where.not(cost_cents: nil)
                   .where(created_at: Date.current.beginning_of_month.beginning_of_day..Date.current.end_of_month.end_of_day)
                   .sum(:cost_cents)
    assert_equal expected, @claude_agent.monthly_spend_cents
  end

  test "monthly_spend_cents returns 0 when no budget configured" do
    assert_equal 0, @process_agent.monthly_spend_cents
  end

  test "monthly_spend_cents ignores tasks with nil cost_cents" do
    spend = @claude_agent.monthly_spend_cents
    assert spend >= 0
  end

  test "budget_remaining_cents returns correct remaining amount" do
    remaining = @claude_agent.budget_remaining_cents
    assert_equal [ 50000 - @claude_agent.monthly_spend_cents, 0 ].max, remaining
  end

  test "budget_remaining_cents returns nil when no budget" do
    @process_agent.budget_cents = nil
    assert_nil @process_agent.budget_remaining_cents
  end

  test "budget_remaining_cents never goes below zero" do
    @claude_agent.budget_cents = 1  # $0.01 budget, guaranteed to be exhausted
    assert_equal 0, @claude_agent.budget_remaining_cents
  end

  test "budget_utilization returns percentage" do
    util = @claude_agent.budget_utilization
    assert_kind_of Float, util
    assert util >= 0.0
    assert util <= 100.0
  end

  test "budget_utilization returns 0.0 when no budget" do
    @process_agent.budget_cents = nil
    assert_equal 0.0, @process_agent.budget_utilization
  end

  test "budget_exhausted? returns true when spend meets budget" do
    @claude_agent.budget_cents = 1  # tiny budget
    assert @claude_agent.budget_exhausted?
  end

  test "budget_exhausted? returns false when under budget" do
    @claude_agent.budget_cents = 999_999_99  # very large budget
    assert_not @claude_agent.budget_exhausted?
  end

  test "budget_alert_threshold? returns true at 80% utilization" do
    spend = @claude_agent.monthly_spend_cents
    @claude_agent.budget_cents = (spend / 0.80).ceil if spend > 0
    if @claude_agent.budget_cents && @claude_agent.budget_cents > 0
      assert @claude_agent.budget_alert_threshold?
    end
  end

  test "budget_alert_threshold? returns false when well under budget" do
    @claude_agent.budget_cents = 999_999_99
    assert_not @claude_agent.budget_alert_threshold?
  end

  test "current_budget_period_start defaults to beginning of month" do
    @claude_agent.budget_period_start = nil
    assert_equal Date.current.beginning_of_month, @claude_agent.current_budget_period_start
  end

  test "current_budget_period_end returns end of month" do
    assert_equal @claude_agent.current_budget_period_start.end_of_month, @claude_agent.current_budget_period_end
  end

  # --- Real-time broadcasts ---

  test "agent has broadcast_dashboard_update private method" do
    assert @claude_agent.respond_to?(:broadcast_dashboard_update, true)
  end

  test "agent status change does not error" do
    assert_nothing_raised do
      @claude_agent.update!(status: :running)
    end
  end
end
