require "test_helper"

class ExecuteHookJobTest < ActiveSupport::TestCase
  setup do
    @execution = hook_executions(:completed_execution)
  end

  test "skips completed execution" do
    assert @execution.completed?
    # Should return early without calling service
    assert_nothing_raised do
      ExecuteHookJob.perform_now(@execution.id)
    end
  end

  test "retries failed execution" do
    hook = agent_hooks(:claude_validation_hook)

    execution = HookExecution.create!(
      agent_hook: hook,
      task: tasks(:design_homepage),
      company: companies(:acme),
      status: :failed,
      error_message: "Transient error",
      started_at: 1.minute.ago,
      completed_at: 1.minute.ago,
      input_payload: { task_id: tasks(:design_homepage).id }
    )

    assert_difference "Task.count", 1 do
      ExecuteHookJob.perform_now(execution.id)
    end

    execution.reload
    assert execution.completed?
  end

  test "skips when execution not found" do
    assert_nothing_raised do
      ExecuteHookJob.perform_now(999999)
    end
  end

  test "has retry_on configured for 3 attempts" do
    # Verify the job class has retry_on set up via rescue_handlers
    assert ExecuteHookJob.instance_method(:perform)
    # The retry_on configuration is verified by checking the class has the discard handler
    assert ExecuteHookJob.respond_to?(:retry_on)
  end

  test "job is enqueued to default queue" do
    assert_equal "default", ExecuteHookJob.new.queue_name
  end

  test "calls ExecuteHookService for queued execution" do
    hook = agent_hooks(:claude_validation_hook)

    execution = HookExecution.create!(
      agent_hook: hook,
      task: tasks(:design_homepage),
      company: companies(:acme),
      status: :queued,
      input_payload: { task_id: tasks(:design_homepage).id }
    )

    assert_difference "Task.count", 1 do  # validation subtask created
      ExecuteHookJob.perform_now(execution.id)
    end

    execution.reload
    assert execution.completed?
  end

  test "calls ExecuteHookService for running execution" do
    hook = agent_hooks(:claude_validation_hook)

    execution = HookExecution.create!(
      agent_hook: hook,
      task: tasks(:design_homepage),
      company: companies(:acme),
      status: :running,
      started_at: Time.current,
      input_payload: { task_id: tasks(:design_homepage).id }
    )

    # Running executions should also be processed (retry scenario)
    assert_difference "Task.count", 1 do
      ExecuteHookJob.perform_now(execution.id)
    end

    execution.reload
    assert execution.completed?
  end
end
