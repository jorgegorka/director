require "test_helper"
require "webmock/minitest"

class ExecuteHookServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @task = tasks(:design_homepage)  # in_progress, assigned to cto

    # Create fresh queued execution for trigger_agent hook
    @trigger_hook = role_hooks(:cto_validation_hook)

    @trigger_execution = HookExecution.create!(
      role_hook: @trigger_hook,
      task: @task,
      company: @company,
      status: :queued,
      input_payload: { task_id: @task.id, task_title: @task.title }
    )

    # Create fresh queued execution for webhook hook
    @webhook_hook = role_hooks(:cto_webhook_hook)
    @webhook_execution = HookExecution.create!(
      role_hook: @webhook_hook,
      task: @task,
      company: @company,
      status: :queued,
      input_payload: { task_id: @task.id, task_title: @task.title }
    )
  end

  # --- trigger_agent dispatch ---

  test "trigger_agent creates validation subtask assigned to target role" do
    ExecuteHookService.call(@trigger_execution)

    subtask = Task.find_by(parent_task: @task, assignee: @developer)
    assert subtask.present?, "Validation subtask should be created"
    assert_equal "Validate: #{@task.title}", subtask.title
    assert_equal @task.company_id, subtask.company_id
    assert_equal @task.id, subtask.parent_task_id
    assert subtask.open?
  end

  test "trigger_agent subtask description includes hook prompt" do
    ExecuteHookService.call(@trigger_execution)
    subtask = Task.find_by(parent_task: @task, assignee: @developer)
    assert_includes subtask.description, "Review the completed work for correctness and quality."
  end

  test "trigger_agent subtask description includes original task title" do
    ExecuteHookService.call(@trigger_execution)
    subtask = Task.find_by(parent_task: @task, assignee: @developer)
    assert_includes subtask.description, @task.title
  end

  test "trigger_agent wakes target role via Roles::Waking with hook_triggered" do
    assert_difference "HeartbeatEvent.count", 2 do
      ExecuteHookService.call(@trigger_execution)
    end

    hook_event = HeartbeatEvent.where(trigger_type: :hook_triggered).last
    assert hook_event.present?
    assert_equal @developer.id, hook_event.role_id
    assert_equal "RoleHook##{@trigger_hook.id}", hook_event.trigger_source
  end

  test "trigger_agent marks execution as completed with output" do
    ExecuteHookService.call(@trigger_execution)
    @trigger_execution.reload

    assert @trigger_execution.completed?
    assert @trigger_execution.started_at.present?
    assert @trigger_execution.completed_at.present?
    assert_equal "validation_created", @trigger_execution.output_payload["result"]
    assert @trigger_execution.output_payload["validation_task_id"].present?
  end

  test "trigger_agent raises when target role not found" do
    @trigger_hook.update_columns(action_config: { "target_role_id" => 999999 })

    assert_raises(RuntimeError, /Target role not found/) do
      ExecuteHookService.call(@trigger_execution)
    end

    @trigger_execution.reload
    assert @trigger_execution.failed?
    assert_includes @trigger_execution.error_message, "Target role not found"
  end

  # --- webhook dispatch ---

  test "webhook POSTs JSON payload to configured URL" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 200, body: '{"ok": true}')

    ExecuteHookService.call(@webhook_execution)

    assert_requested(:post, "https://hooks.example.com/task-started") do |req|
      payload = JSON.parse(req.body)
      payload["event"] == "after_task_start" &&
        payload["task"]["id"] == @task.id &&
        payload["task"]["title"] == @task.title
    end
  end

  test "webhook includes custom headers from action_config" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 200, body: '{"ok": true}')

    ExecuteHookService.call(@webhook_execution)

    assert_requested(:post, "https://hooks.example.com/task-started") do |req|
      req.headers["Authorization"] == "Bearer test-token" &&
        req.headers["Content-Type"] == "application/json"
    end
  end

  test "webhook marks execution as completed on success" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 200, body: '{"ok": true}')

    ExecuteHookService.call(@webhook_execution)
    @webhook_execution.reload

    assert @webhook_execution.completed?
    assert_equal "webhook_delivered", @webhook_execution.output_payload["result"]
    assert_equal "200", @webhook_execution.output_payload["response_code"]
  end

  test "webhook raises on non-success HTTP response" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(RuntimeError, /Webhook returned 500/) do
      ExecuteHookService.call(@webhook_execution)
    end

    @webhook_execution.reload
    assert @webhook_execution.failed?
    assert_includes @webhook_execution.error_message, "Webhook returned 500"
  end

  test "webhook raises on network error" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_timeout

    assert_raises do
      ExecuteHookService.call(@webhook_execution)
    end

    @webhook_execution.reload
    assert @webhook_execution.failed?
  end

  # --- Audit events ---

  test "records audit event on successful execution" do
    assert_difference "AuditEvent.count", 1 do
      ExecuteHookService.call(@trigger_execution)
    end

    audit = AuditEvent.last
    assert_equal "hook_executed", audit.action
    assert_equal @trigger_hook, audit.auditable
    assert_equal @cto, audit.actor
    assert_equal @company, audit.company
    assert_equal @task.id, audit.metadata["task_id"]
  end

  test "does not record audit event on failure" do
    @trigger_hook.update_columns(action_config: { "target_role_id" => 999999 })

    audit_count_before = AuditEvent.count
    assert_raises(RuntimeError) do
      ExecuteHookService.call(@trigger_execution)
    end
    assert_equal audit_count_before, AuditEvent.count
  end

  # --- Execution lifecycle ---

  test "execution transitions from queued to running to completed" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 200, body: '{"ok": true}')

    assert @webhook_execution.queued?
    ExecuteHookService.call(@webhook_execution)
    @webhook_execution.reload

    assert @webhook_execution.completed?
    assert @webhook_execution.started_at.present?
    assert @webhook_execution.completed_at.present?
  end

  test "execution transitions from queued to running to failed on error" do
    stub_request(:post, "https://hooks.example.com/task-started")
      .to_return(status: 503, body: "Service Unavailable")

    assert_raises(RuntimeError) do
      ExecuteHookService.call(@webhook_execution)
    end
    @webhook_execution.reload

    assert @webhook_execution.failed?
    assert @webhook_execution.started_at.present?
    assert @webhook_execution.completed_at.present?
  end
end
