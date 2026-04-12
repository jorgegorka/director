require "test_helper"

class ApprovalGateTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @gate = approval_gates(:cto_task_creation_gate)
  end

  # --- Validations ---

  test "valid with role, action_type, and enabled" do
    gate = ApprovalGate.new(role: @role, action_type: "status_change")
    assert gate.valid?
  end

  test "invalid without action_type" do
    gate = ApprovalGate.new(role: @role, action_type: nil)
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "can't be blank"
  end

  test "invalid with unrecognized action_type" do
    gate = ApprovalGate.new(role: @role, action_type: "custom_action")
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "custom_action is not a valid gatable action"
  end

  test "invalid with duplicate action_type for same role" do
    gate = ApprovalGate.new(role: @role, action_type: "task_creation")
    assert_not gate.valid?
    assert_includes gate.errors[:action_type], "gate already exists for this role"
  end

  test "allows same action_type for different roles" do
    gate = ApprovalGate.new(role: roles(:developer), action_type: "task_creation")
    assert gate.valid?
  end

  test "all GATABLE_ACTIONS are accepted" do
    other_agent = roles(:process_role)
    ApprovalGate::GATABLE_ACTIONS.each do |action|
      gate = ApprovalGate.new(role: other_agent, action_type: action)
      assert gate.valid?, "Expected #{action} to be valid"
    end
  end

  # --- Associations ---

  test "belongs to role" do
    assert_equal @role, @gate.role
  end

  test "destroying role destroys its gates" do
    gate_count = @role.approval_gates.count
    assert gate_count > 0
    @role.created_tasks.update_all(creator_id: roles(:ceo).id)
    assert_difference "ApprovalGate.count", -gate_count do
      @role.destroy
    end
  end

  # --- Scopes ---

  test "enabled scope returns only enabled gates" do
    enabled = ApprovalGate.enabled
    enabled.each { |g| assert g.enabled? }
    assert_not_includes enabled, approval_gates(:cto_delegation_gate_disabled)
  end

  test "disabled scope returns only disabled gates" do
    disabled = ApprovalGate.disabled
    disabled.each { |g| assert_not g.enabled? }
    assert_includes disabled, approval_gates(:cto_delegation_gate_disabled)
  end

  test "for_action returns gates matching action_type" do
    gates = ApprovalGate.for_action("task_creation")
    gates.each { |g| assert_equal "task_creation", g.action_type }
  end

  # --- Role helper methods ---

  test "role.gate_enabled? returns true for enabled gate" do
    assert @role.gate_enabled?("task_creation")
  end

  test "role.gate_enabled? returns false for disabled gate" do
    assert_not @role.gate_enabled?("task_delegation")
  end

  test "role.gate_enabled? returns false for non-existent gate" do
    assert_not @role.gate_enabled?("status_change")
  end

  test "role.has_any_gates? returns true when role has enabled gates" do
    assert @role.has_any_gates?
  end

  test "role.has_any_gates? returns false when no enabled gates" do
    role = roles(:process_role)
    assert_not role.has_any_gates?
  end
end
