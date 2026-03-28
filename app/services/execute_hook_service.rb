class ExecuteHookService
  attr_reader :execution

  def initialize(execution)
    @execution = execution
  end

  def self.call(execution)
    new(execution).call
  end

  def call
    execution.mark_running!
    output = dispatch
    execution.mark_completed!(output: output)
    record_audit_event
    execution
  rescue StandardError => e
    execution.mark_failed!(error_message: e.message)
    raise  # Re-raise so ExecuteHookJob retry_on can catch it
  end

  private

  delegate :agent_hook, to: :execution
  delegate :task, to: :execution

  def dispatch
    if agent_hook.trigger_agent?
      dispatch_trigger_agent
    elsif agent_hook.webhook?
      dispatch_webhook
    else
      raise "Unknown action_type: #{agent_hook.action_type} for hook #{agent_hook.id}"
    end
  end

  def dispatch_trigger_agent
    target = agent_hook.target_agent
    raise "Target agent not found for hook #{agent_hook.id}" unless target
    raise "Target agent #{target.id} is terminated" if target.terminated?

    validation_task = Task.create!(
      title: "Validate: #{task.title}",
      description: build_validation_description,
      company_id: task.company_id,
      assignee: target,
      parent_task: task,
      status: :open,
      priority: task.priority
    )

    WakeAgentService.call(
      agent: target,
      trigger_type: :hook_triggered,
      trigger_source: "AgentHook##{agent_hook.id}",
      context: {
        hook_id: agent_hook.id,
        hook_name: agent_hook.name,
        validation_task_id: validation_task.id,
        original_task_id: task.id,
        original_task_title: task.title
      }
    )

    { result: "validation_created", validation_task_id: validation_task.id, target_agent_id: target.id }
  end

  def build_validation_description
    prompt = agent_hook.action_config&.dig("prompt")
    parts = []
    parts << "Hook: #{agent_hook.name}" if agent_hook.name.present?
    parts << "Original task: #{task.title} (#{task.status})"
    parts << prompt if prompt.present?
    parts.join("\n\n")
  end

  def dispatch_webhook
    url = agent_hook.action_config["url"]
    raise "Webhook URL not configured for hook #{agent_hook.id}" unless url

    uri = URI.parse(url)
    headers = build_webhook_headers
    timeout = (agent_hook.action_config["timeout"] || 30).to_i
    payload = build_webhook_payload

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Webhook returned #{response.code}: #{response.body&.truncate(500)}"
    end

    { result: "webhook_delivered", response_code: response.code, response_body: response.body&.truncate(1000) }
  end

  def build_webhook_headers
    custom_headers = agent_hook.action_config["headers"] || {}
    { "Content-Type" => "application/json" }.merge(custom_headers)
  end

  def build_webhook_payload
    {
      event: agent_hook.lifecycle_event,
      hook_id: agent_hook.id,
      hook_name: agent_hook.name,
      task: {
        id: task.id,
        title: task.title,
        status: task.status,
        description: task.description,
        assignee_id: task.assignee_id,
        company_id: task.company_id,
        completed_at: task.completed_at&.iso8601
      },
      triggered_at: Time.current.iso8601
    }
  end

  def record_audit_event
    agent_hook.record_audit_event!(
      actor: agent_hook.agent,
      action: "hook_executed",
      company: task.company,
      metadata: {
        hook_name: agent_hook.name,
        action_type: agent_hook.action_type,
        lifecycle_event: agent_hook.lifecycle_event,
        task_id: task.id,
        task_title: task.title,
        execution_id: execution.id
      }
    )
  end
end
