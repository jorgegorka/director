require "test_helper"

class SubAgentInvocationTest < ActiveSupport::TestCase
  setup do
    @role_run = role_runs(:completed_run)
    @role_run.update_column(:cost_cents, 500)
  end

  test "start! creates a running invocation scoped to the role_run's project" do
    invocation = SubAgentInvocation.start!(
      role_run: @role_run,
      sub_agent_name: "create_task",
      input_summary: "make a task"
    )

    assert invocation.running?
    assert_equal @role_run, invocation.role_run
    assert_equal @role_run.project, invocation.project
    assert_equal "create_task", invocation.sub_agent_name
    assert_equal 0, invocation.cost_cents
  end

  test "finish! marks completed and rolls cost up into the parent RoleRun" do
    invocation = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "review_task")

    invocation.finish!(
      result_summary: "approved",
      cost_cents: 120,
      duration_ms: 3400,
      iterations: 3
    )

    assert invocation.reload.completed?
    assert_equal 120, invocation.cost_cents
    assert_equal 3400, invocation.duration_ms
    assert_equal 3, invocation.iterations
    assert_equal 620, @role_run.reload.cost_cents
  end

  test "finish! with zero cost does not write to RoleRun" do
    invocation = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "create_task")
    original_cost = @role_run.cost_cents

    invocation.finish!(result_summary: "ok", cost_cents: 0, duration_ms: 10, iterations: 1)

    assert_equal original_cost, @role_run.reload.cost_cents
  end

  test "fail! marks failed, records error, and still rolls partial cost up" do
    invocation = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "hire_role")

    invocation.fail!(error_message: "LLM timeout", cost_cents: 40, duration_ms: 9000, iterations: 1)

    assert invocation.reload.failed?
    assert_equal "LLM timeout", invocation.error_message
    assert_equal 40, invocation.cost_cents
    assert_equal 540, @role_run.reload.cost_cents
  end

  test "enqueue! creates a queued invocation for async dispatch" do
    invocation = SubAgentInvocation.enqueue!(
      role_run: @role_run,
      sub_agent_name: "create_task",
      input_summary: "delegate onboarding redesign"
    )

    assert invocation.queued?
    assert_equal @role_run, invocation.role_run
    assert_equal @role_run.project, invocation.project
    assert_equal "delegate onboarding redesign", invocation.input_summary
    assert_not invocation.terminal?
  end

  test "mark_running! flips queued to running" do
    invocation = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task")

    invocation.mark_running!

    assert invocation.reload.running?
  end

  test "terminal? is true only for completed and failed invocations" do
    queued = SubAgentInvocation.enqueue!(role_run: @role_run, sub_agent_name: "create_task")
    running = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "review_task")
    completed = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "create_task")
    completed.finish!(result_summary: "ok", cost_cents: 0, duration_ms: 10, iterations: 1)
    failed = SubAgentInvocation.start!(role_run: @role_run, sub_agent_name: "hire_role")
    failed.fail!(error_message: "nope", cost_cents: 0, duration_ms: 5, iterations: 0)

    assert_not queued.terminal?
    assert_not running.terminal?
    assert completed.terminal?
    assert failed.terminal?
  end
end
