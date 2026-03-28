require "test_helper"

class HookExecutionTest < ActiveSupport::TestCase
  setup do
    @completed_execution = hook_executions(:completed_execution)
    @failed_execution = hook_executions(:failed_execution)
    @validation_hook = agent_hooks(:claude_validation_hook)
    @company = companies(:acme)
  end

  # --- Validations ---

  test "valid with agent_hook, task, company, and status" do
    execution = HookExecution.new(
      agent_hook: @validation_hook,
      task: tasks(:design_homepage),
      company: @company,
      status: :queued
    )
    assert execution.valid?
  end

  # --- Enums ---

  test "status enum: queued?" do
    execution = HookExecution.new(status: :queued)
    assert execution.queued?
  end

  test "status enum: running?" do
    execution = HookExecution.new(status: :running)
    assert execution.running?
  end

  test "status enum: completed?" do
    assert @completed_execution.completed?
  end

  test "status enum: failed?" do
    assert @failed_execution.failed?
  end

  test "status enum covers all values" do
    %i[queued running completed failed].each do |s|
      execution = HookExecution.new(status: s)
      assert execution.send(:"#{s}?"), "Expected #{s}? to return true"
    end
  end

  # --- Associations ---

  test "belongs to agent_hook" do
    assert_equal @validation_hook, @completed_execution.agent_hook
  end

  test "belongs to task" do
    assert_equal tasks(:completed_task), @completed_execution.task
  end

  test "belongs to company" do
    assert_equal @company, @completed_execution.company
  end

  # --- Mark methods ---

  test "mark_running! sets status and started_at" do
    execution = HookExecution.create!(
      agent_hook: @validation_hook,
      task: tasks(:design_homepage),
      company: @company,
      status: :queued
    )
    assert execution.queued?
    assert_nil execution.started_at

    execution.mark_running!
    assert execution.running?
    assert_not_nil execution.started_at
  end

  test "mark_completed! sets status, output_payload, and completed_at" do
    execution = HookExecution.create!(
      agent_hook: @validation_hook,
      task: tasks(:design_homepage),
      company: @company,
      status: :running,
      started_at: 1.minute.ago
    )

    execution.mark_completed!(output: { "result" => "success" })
    assert execution.completed?
    assert_equal({ "result" => "success" }, execution.output_payload)
    assert_not_nil execution.completed_at
  end

  test "mark_failed! sets status, error_message, and completed_at" do
    execution = HookExecution.create!(
      agent_hook: @validation_hook,
      task: tasks(:design_homepage),
      company: @company,
      status: :running,
      started_at: 1.minute.ago
    )

    execution.mark_failed!(error_message: "Connection timeout")
    assert execution.failed?
    assert_equal "Connection timeout", execution.error_message
    assert_not_nil execution.completed_at
  end

  # --- Duration ---

  test "duration_seconds returns elapsed time between started_at and completed_at" do
    duration = @completed_execution.duration_seconds
    assert_not_nil duration
    assert_kind_of Numeric, duration
    assert duration > 0
  end

  test "duration_seconds returns nil when started_at is nil" do
    execution = HookExecution.new(completed_at: Time.current)
    assert_nil execution.duration_seconds
  end

  test "duration_seconds returns nil when completed_at is nil" do
    execution = HookExecution.new(started_at: Time.current)
    assert_nil execution.duration_seconds
  end

  # --- Scopes ---

  test "chronological orders by created_at ascending" do
    executions = HookExecution.chronological
    timestamps = executions.map(&:created_at)
    assert_equal timestamps, timestamps.sort
  end

  test "reverse_chronological orders by created_at descending" do
    executions = HookExecution.reverse_chronological
    timestamps = executions.map(&:created_at)
    assert_equal timestamps, timestamps.sort.reverse
  end

  test "for_task filters by task" do
    task = tasks(:completed_task)
    executions = HookExecution.for_task(task)
    assert executions.all? { |e| e.task_id == task.id }
    assert_includes executions, @completed_execution
  end

  # --- Defaults ---

  test "status defaults to queued" do
    execution = HookExecution.new
    assert_equal "queued", execution.status
  end

  test "input_payload defaults to empty hash" do
    execution = HookExecution.new
    assert_equal({}, execution.input_payload)
  end

  test "output_payload defaults to empty hash" do
    execution = HookExecution.new
    assert_equal({}, execution.output_payload)
  end
end
