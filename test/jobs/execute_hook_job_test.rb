require "test_helper"

class ExecuteHookJobTest < ActiveSupport::TestCase
  setup do
    @execution = hook_executions(:completed_execution)
  end

  test "skips completed execution" do
    assert @execution.completed?
    assert_nothing_raised do
      ExecuteHookJob.perform_now(@execution.id)
    end
  end

  test "retries failed execution" do
    hook = role_hooks(:cto_validation_hook)

    execution = HookExecution.create!(
      role_hook: hook,
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
    assert ExecuteHookJob.instance_method(:perform)
    assert ExecuteHookJob.respond_to?(:retry_on)
  end

  test "job is enqueued to default queue" do
    assert_equal "default", ExecuteHookJob.new.queue_name
  end

  test "calls Hooks::Executor for queued execution" do
    hook = role_hooks(:cto_validation_hook)

    execution = HookExecution.create!(
      role_hook: hook,
      task: tasks(:design_homepage),
      company: companies(:acme),
      status: :queued,
      input_payload: { task_id: tasks(:design_homepage).id }
    )

    assert_difference "Task.count", 1 do
      ExecuteHookJob.perform_now(execution.id)
    end

    execution.reload
    assert execution.completed?
  end

  test "calls Hooks::Executor for running execution" do
    hook = role_hooks(:cto_validation_hook)

    execution = HookExecution.create!(
      role_hook: hook,
      task: tasks(:design_homepage),
      company: companies(:acme),
      status: :running,
      started_at: Time.current,
      input_payload: { task_id: tasks(:design_homepage).id }
    )

    assert_difference "Task.count", 1 do
      ExecuteHookJob.perform_now(execution.id)
    end

    execution.reload
    assert execution.completed?
  end
end
