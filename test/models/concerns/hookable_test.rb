require "test_helper"

class HookableTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @company = companies(:acme)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @task = tasks(:design_homepage)  # in_progress, assigned to claude_agent
    @open_task = tasks(:fix_login_bug)  # open, assigned to http_agent
    @validation_hook = agent_hooks(:claude_validation_hook)  # after_task_complete, trigger_agent, enabled
    @webhook_hook = agent_hooks(:claude_webhook_hook)  # after_task_start, webhook, enabled
    @disabled_hook = agent_hooks(:disabled_hook)  # after_task_complete, disabled, on http_agent
  end

  # --- Status transition to completed triggers after_task_complete hooks ---

  test "transitioning task to completed enqueues ExecuteHookJob for matching enabled hooks" do
    # design_homepage is in_progress, assigned to claude_agent
    # claude_agent has claude_validation_hook (after_task_complete, enabled)
    assert_difference "HookExecution.count", 1 do
      assert_enqueued_with(job: ExecuteHookJob) do
        @task.update!(status: :completed)
      end
    end

    execution = HookExecution.last
    assert_equal "queued", execution.status
    assert_equal @validation_hook.id, execution.agent_hook_id
    assert_equal @task.id, execution.task_id
    assert_equal @company.id, execution.company_id
  end

  test "input_payload contains task and hook context" do
    @task.update!(status: :completed)
    execution = HookExecution.last

    payload = execution.input_payload
    assert_equal @task.id, payload["task_id"]
    assert_equal @task.title, payload["task_title"]
    assert_equal "completed", payload["task_status"]
    assert_equal @claude_agent.id, payload["agent_id"]
    assert_equal @claude_agent.name, payload["agent_name"]
    assert_equal "after_task_complete", payload["lifecycle_event"]
    assert_equal "trigger_agent", payload["action_type"]
    assert payload["triggered_at"].present?
  end

  # --- Status transition to in_progress triggers after_task_start hooks ---

  test "transitioning task to in_progress enqueues hooks for after_task_start" do
    # fix_login_bug is open, assigned to http_agent
    # http_agent has no enabled after_task_start hooks (disabled_hook is after_task_complete)
    # So use a task assigned to claude_agent instead
    task = tasks(:fix_login_bug)
    task.update_columns(assignee_id: @claude_agent.id)
    task.reload

    # claude_agent has after_task_start hooks: claude_webhook_hook (pos 0), claude_start_validation_hook (pos 1)
    assert_difference "HookExecution.count", 2 do
      task.update!(status: :in_progress)
    end
  end

  test "hooks fire in position order" do
    task = tasks(:fix_login_bug)
    task.update_columns(assignee_id: @claude_agent.id)
    task.reload

    task.update!(status: :in_progress)

    executions = HookExecution.where(task: task).order(:created_at)
    # claude_webhook_hook (position 0) should be first, claude_start_validation_hook (position 1) second
    assert_equal agent_hooks(:claude_webhook_hook).id, executions.first.agent_hook_id
    assert_equal agent_hooks(:claude_start_validation_hook).id, executions.second.agent_hook_id
  end

  # --- Disabled hooks are skipped ---

  test "disabled hooks are not enqueued" do
    # disabled_hook is on http_agent, after_task_complete, disabled
    # http_agent has no enabled after_task_complete hooks
    task = tasks(:fix_login_bug)  # assigned to http_agent, status: open

    assert_no_difference "HookExecution.count" do
      task.update!(status: :completed)
    end
  end

  # --- Non-triggering transitions ---

  test "transitioning to open does not enqueue hooks" do
    # in_progress -> open is not a hookable transition
    assert_no_difference "HookExecution.count" do
      @task.update!(status: :open)
    end
  end

  test "transitioning to blocked does not enqueue hooks" do
    assert_no_difference "HookExecution.count" do
      @task.update!(status: :blocked)
    end
  end

  test "transitioning to cancelled does not enqueue hooks" do
    assert_no_difference "HookExecution.count" do
      @task.update!(status: :cancelled)
    end
  end

  # --- No assignee ---

  test "task without assignee does not enqueue hooks" do
    task = tasks(:write_tests)  # no assignee
    assert_no_difference "HookExecution.count" do
      task.update!(status: :completed)
    end
  end

  # --- No status change ---

  test "updating task without status change does not enqueue hooks" do
    assert_no_difference "HookExecution.count" do
      @task.update!(title: "Updated title")
    end
  end

  # --- Task created directly in hookable status ---

  test "creating task directly in in_progress status enqueues hooks" do
    # claude_agent has 2 after_task_start hooks (claude_webhook_hook pos 0, claude_start_validation_hook pos 1)
    assert_difference "HookExecution.count", 2 do
      Task.create!(
        title: "Direct start task",
        company: @company,
        assignee: @claude_agent,
        status: :in_progress
      )
    end
  end

  # --- Validation feedback detection ---

  test "completing a subtask with parent_task enqueues ProcessValidationResultJob" do
    subtask = tasks(:subtask_one)  # has parent_task: design_homepage, status: open
    subtask.update_columns(assignee_id: @http_agent.id)
    subtask.reload

    assert_enqueued_with(job: ProcessValidationResultJob, args: [ subtask.id ]) do
      subtask.update!(status: :completed)
    end
  end

  test "completing a root task does not enqueue ProcessValidationResultJob" do
    # design_homepage has no parent_task
    assert_no_enqueued_jobs(only: ProcessValidationResultJob) do
      @task.update!(status: :completed)
    end
  end

  test "completing a subtask without parent_task does not enqueue ProcessValidationResultJob" do
    task = tasks(:write_tests)  # no assignee, no parent
    assert_no_enqueued_jobs(only: ProcessValidationResultJob) do
      task.update!(status: :completed)
    end
  end

  test "transitioning subtask to in_progress does not enqueue ProcessValidationResultJob" do
    subtask = tasks(:subtask_one)
    subtask.update_columns(assignee_id: @http_agent.id)
    subtask.reload

    assert_no_enqueued_jobs(only: ProcessValidationResultJob) do
      subtask.update!(status: :in_progress)
    end
  end
end
