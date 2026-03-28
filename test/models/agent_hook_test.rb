require "test_helper"

class AgentHookTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @validation_hook = agent_hooks(:claude_validation_hook)
    @webhook_hook = agent_hooks(:claude_webhook_hook)
    @disabled_hook = agent_hooks(:disabled_hook)
  end

  # --- Validations ---

  test "valid trigger_agent hook with required fields" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "target_agent_id" => @http_agent.id }
    )
    assert hook.valid?
  end

  test "valid webhook hook with required fields" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "after_task_start",
      action_type: :webhook,
      action_config: { "url" => "https://example.com/hook" }
    )
    assert hook.valid?
  end

  test "invalid without lifecycle_event" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      action_type: :trigger_agent,
      action_config: { "target_agent_id" => @http_agent.id }
    )
    assert_not hook.valid?
    assert hook.errors[:lifecycle_event].any?
  end

  test "invalid with unknown lifecycle_event" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "before_task_delete",
      action_type: :trigger_agent,
      action_config: { "target_agent_id" => @http_agent.id }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:lifecycle_event].join, "is not a valid lifecycle event"
  end

  test "invalid trigger_agent hook without target_agent_id in config" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "prompt" => "Review this" }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:action_config].join, "must include target_agent_id"
  end

  test "invalid webhook hook without url in config" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "after_task_start",
      action_type: :webhook,
      action_config: { "headers" => {} }
    )
    assert_not hook.valid?
    assert_includes hook.errors[:action_config].join, "must include url"
  end

  test "invalid with negative position" do
    hook = AgentHook.new(
      agent: @claude_agent,
      company: @company,
      lifecycle_event: "after_task_complete",
      action_type: :trigger_agent,
      action_config: { "target_agent_id" => @http_agent.id },
      position: -1
    )
    assert_not hook.valid?
    assert hook.errors[:position].any?
  end

  test "valid lifecycle events are after_task_start and after_task_complete" do
    assert_equal %w[after_task_start after_task_complete], AgentHook::LIFECYCLE_EVENTS
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

  test "belongs to agent" do
    assert_equal @claude_agent, @validation_hook.agent
  end

  test "belongs to company via Tenantable" do
    assert_equal @company, @validation_hook.company
  end

  test "has many hook_executions" do
    assert @validation_hook.respond_to?(:hook_executions)
    assert_includes @validation_hook.hook_executions, hook_executions(:completed_execution)
  end

  # --- Scopes ---

  test "enabled scope returns only enabled hooks" do
    enabled = AgentHook.enabled
    assert_includes enabled, @validation_hook
    assert_includes enabled, @webhook_hook
    assert_not_includes enabled, @disabled_hook
  end

  test "disabled scope returns only disabled hooks" do
    disabled = AgentHook.disabled
    assert_includes disabled, @disabled_hook
    assert_not_includes disabled, @validation_hook
  end

  test "for_event scope filters by lifecycle_event" do
    after_complete = AgentHook.for_event("after_task_complete")
    assert_includes after_complete, @validation_hook
    assert_not_includes after_complete, @webhook_hook

    after_start = AgentHook.for_event("after_task_start")
    assert_includes after_start, @webhook_hook
    assert_not_includes after_start, @validation_hook
  end

  test "ordered scope orders by position then created_at" do
    hooks = AgentHook.ordered
    positions = hooks.map(&:position)
    assert_equal positions, positions.sort
  end

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    hooks = AgentHook.for_current_company
    hooks.each do |hook|
      assert_equal @company.id, hook.company_id
    end
  ensure
    Current.company = nil
  end

  # --- Methods ---

  test "target_agent returns agent referenced in action_config" do
    @validation_hook.action_config = { "target_agent_id" => @http_agent.id }
    assert_equal @http_agent, @validation_hook.target_agent
  end

  test "target_agent returns nil for webhook hooks" do
    assert_nil @webhook_hook.target_agent
  end

  test "target_agent returns nil when target_agent_id is missing from config" do
    @validation_hook.action_config = {}
    assert_nil @validation_hook.target_agent
  end

  test "target_agent returns nil when target agent does not exist" do
    @validation_hook.action_config = { "target_agent_id" => 999999 }
    assert_nil @validation_hook.target_agent
  end

  # --- Cascade destroy ---

  test "destroying agent destroys its agent_hooks" do
    hook_count = @claude_agent.agent_hooks.count
    assert hook_count > 0
    assert_difference "AgentHook.count", -hook_count do
      @claude_agent.destroy
    end
  end

  test "destroying agent_hook destroys its hook_executions" do
    execution_count = @validation_hook.hook_executions.count
    assert execution_count > 0
    assert_difference "HookExecution.count", -execution_count do
      @validation_hook.destroy
    end
  end

  # --- Defaults ---

  test "enabled defaults to true" do
    hook = AgentHook.new
    assert_equal true, hook.enabled
  end

  test "position defaults to 0" do
    hook = AgentHook.new
    assert_equal 0, hook.position
  end

  test "action_config defaults to empty hash" do
    hook = AgentHook.new
    assert_equal({}, hook.action_config)
  end
end
