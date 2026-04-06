require "test_helper"

class RoleHookTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @validation_hook = role_hooks(:cto_validation_hook)
    @webhook_hook = role_hooks(:cto_webhook_hook)
    @disabled_hook = role_hooks(:disabled_hook)
  end

  # --- Validations ---

  test "valid trigger_agent hook with required fields" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "target_role_id" => @developer.id }
    )
    assert hook.valid?
  end

  test "valid webhook hook with required fields" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "after_task_start",
      action_type: :webhook,
      action_config: { "url" => "https://example.com/hook" }
    )
    assert hook.valid?
  end

  test "invalid without lifecycle_event" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      action_type: :trigger_agent,
      action_config: { "target_role_id" => @developer.id }
    )
    assert_not hook.valid?
    assert hook.errors[:lifecycle_event].any?
  end

  test "invalid with unknown lifecycle_event" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "before_task_delete",
      action_type: :trigger_agent,
      action_config: { "target_role_id" => @developer.id }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:lifecycle_event].join, "is not a valid lifecycle event"
  end

  test "invalid trigger_agent hook without target_role_id in config" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "prompt" => "Review this" }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:action_config].join, "must include target_role_id"
  end

  test "invalid webhook hook without url in config" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "after_task_start",
      action_type: :webhook,
      action_config: { "headers" => {} }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:action_config].join, "must include url"
  end

  test "invalid with negative position" do
    hook = RoleHook.new(
      role: @cto,
      project: @project,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "target_role_id" => @developer.id },
      position: -1
    )
    assert_not hook.valid?
    assert hook.errors[:position].any?
  end

  test "valid lifecycle events are after_task_start and after_task_complete" do
    assert_equal %w[after_task_start after_task_complete], RoleHook::LIFECYCLE_EVENTS
  end

  # --- Enums ---

  test "action_type enum: trigger_agent?" do
    assert @validation_hook.trigger_agent?
    assert_not @webhook_hook.trigger_agent?
  end

  test "action_type enum: webhook?" do
    assert @webhook_hook.webhook?
    assert_not @validation_hook.webhook?
  end

  # --- Associations ---

  test "belongs to role" do
    assert_equal @cto, @validation_hook.role
  end

  test "belongs to project via Tenantable" do
    assert_equal @project, @validation_hook.project
  end

  test "has many hook_executions" do
    assert @validation_hook.respond_to?(:hook_executions)
    assert_includes @validation_hook.hook_executions, hook_executions(:completed_execution)
  end

  # --- Scopes ---

  test "enabled scope returns only enabled hooks" do
    enabled = RoleHook.enabled
    assert_includes enabled, @validation_hook
    assert_includes enabled, @webhook_hook
    assert_not_includes enabled, @disabled_hook
  end

  test "disabled scope returns only disabled hooks" do
    disabled = RoleHook.disabled
    assert_includes disabled, @disabled_hook
    assert_not_includes disabled, @validation_hook
  end

  test "for_event scope filters by lifecycle_event" do
    after_complete = RoleHook.for_event("after_task_complete")
    assert_includes after_complete, @validation_hook
    assert_not_includes after_complete, @webhook_hook

    after_start = RoleHook.for_event("after_task_start")
    assert_includes after_start, @webhook_hook
    assert_not_includes after_start, @validation_hook
  end

  test "ordered scope orders by position then created_at" do
    hooks = RoleHook.ordered
    positions = hooks.map(&:position)
    assert_equal positions, positions.sort
  end

  test "for_current_project scopes to Current.project" do
    Current.project = @project
    hooks = RoleHook.for_current_project
    hooks.each do |hook|
      assert_equal @project.id, hook.project_id
    end
  ensure
    Current.project = nil
  end

  # --- Methods ---

  test "target_role returns role referenced in action_config" do
    @validation_hook.action_config = { "target_role_id" => @developer.id }
    assert_equal @developer, @validation_hook.target_role
  end

  test "target_role returns nil for webhook hooks" do
    assert_nil @webhook_hook.target_role
  end

  test "target_role returns nil when target_role_id is missing from config" do
    @validation_hook.action_config = {}
    assert_nil @validation_hook.target_role
  end

  test "target_role returns nil when target role does not exist" do
    @validation_hook.action_config = { "target_role_id" => 999999 }
    assert_nil @validation_hook.target_role
  end

  # --- Cascade destroy ---

  test "destroying role destroys its role_hooks" do
    hook_count = @cto.role_hooks.count
    assert hook_count > 0
    assert_difference "RoleHook.count", -hook_count do
      @cto.destroy
    end
  end

  test "destroying role_hook destroys its hook_executions" do
    execution_count = @validation_hook.hook_executions.count
    assert execution_count > 0
    assert_difference "HookExecution.count", -execution_count do
      @validation_hook.destroy
    end
  end

  # --- Defaults ---

  test "enabled defaults to true" do
    hook = RoleHook.new
    assert_equal true, hook.enabled
  end

  test "position defaults to 0" do
    hook = RoleHook.new
    assert_equal 0, hook.position
  end

  test "action_config defaults to empty hash" do
    hook = RoleHook.new
    assert_equal({}, hook.action_config)
  end
end
