require "test_helper"

class ApprovalGateTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude_agent)
    @gate = approval_gates(:claude_task_creation_gate)
  end

  # --- Validations ---

  test "valid with agent, action_type, and enabled" do
    gate = ApprovalGate.new(agent: @agent, action_type: "status_change")
    assert gate.valid?
  end

  test "invalid without action_type" do
    gate = ApprovalGate.new(agent: @agent, action_type: nil)
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "can't be blank"
  end

  test "invalid with unrecognized action_type" do
    gate = ApprovalGate.new(agent: @agent, action_type: "custom_action")
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "custom_action is not a valid gatable action"
  end

  test "invalid with duplicate action_type for same agent" do
    gate = ApprovalGate.new(agent: @agent, action_type: "task_creation")
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "gate already exists for this agent"
  end

  test "allows same action_type for different agents" do
    gate = ApprovalGate.new(agent: agents(:http_agent), action_type: "task_creation")
    assert gate.valid?
  end

  test "all GATABLE_ACTIONS are accepted" do
    other_agent = agents(:process_agent)
    ApprovalGate::GATABLE_ACTIONS.each do |action|
      gate = ApprovalGate.new(agent: other_agent, action_type: action)
      assert gate.valid?, "Expected #{action} to be valid"
    end
  end

  # --- Associations ---

  test "belongs to agent" do
    assert_equal @agent, @gate.agent
  end

  test "destroying agent destroys its gates" do
    gate_count = @agent.approval_gates.count
    assert gate_count > 0
    assert_difference "ApprovalGate.count", -gate_count do
      @agent.destroy
    end
  end

  # --- Scopes ---

  test "enabled scope returns only enabled gates" do
    enabled = ApprovalGate.enabled
    enabled.each { |g| assert g.enabled? }
    assert_not_includes enabled, approval_gates(:claude_delegation_gate_disabled)
  end

  test "disabled scope returns only disabled gates" do
    disabled = ApprovalGate.disabled
    disabled.each { |g| assert_not g.enabled? }
    assert_includes disabled, approval_gates(:claude_delegation_gate_disabled)
  end

  test "for_action returns gates matching action_type" do
    gates = ApprovalGate.for_action("task_creation")
    gates.each { |g| assert_equal "task_creation", g.action_type }
  end

  # --- Agent helper methods ---

  test "agent.gate_enabled? returns true for enabled gate" do
    assert @agent.gate_enabled?("task_creation")
  end

  test "agent.gate_enabled? returns false for disabled gate" do
    assert_not @agent.gate_enabled?("task_delegation")
  end

  test "agent.gate_enabled? returns false for non-existent gate" do
    assert_not @agent.gate_enabled?("status_change")
  end

  test "agent.has_any_gates? returns true when agent has enabled gates" do
    assert @agent.has_any_gates?
  end

  test "agent.has_any_gates? returns false when no enabled gates" do
    agent = agents(:process_agent)
    assert_not agent.has_any_gates?
  end
end
