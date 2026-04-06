module Hooks
  class Executor
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

    delegate :role_hook, to: :execution
    delegate :task, to: :execution

    def dispatch
      if role_hook.trigger_agent?
        dispatch_trigger_role
      elsif role_hook.webhook?
        dispatch_webhook
      else
        raise "Unknown action_type: #{role_hook.action_type} for hook #{role_hook.id}"
      end
    end

    def dispatch_trigger_role
      target = role_hook.target_role
      raise "Target role not found for hook #{role_hook.id}" unless target
      raise "Target role #{target.id} is terminated" if target.terminated?

      validation_task = Task.create!(
        title: "Validate: #{task.title}",
        description: build_validation_description,
        project_id: task.project_id,
        assignee: target,
        parent_task: task,
        status: :open,
        priority: task.priority
      )

      Roles::Waking.call(
        role: target,
        trigger_type: :hook_triggered,
        trigger_source: "RoleHook##{role_hook.id}",
        context: {
          hook_id: role_hook.id,
          hook_name: role_hook.name,
          validation_task_id: validation_task.id,
          original_task_id: task.id,
          original_task_title: task.title
        }
      )

      { result: "validation_created", validation_task_id: validation_task.id, target_role_id: target.id }
    end

    def build_validation_description
      prompt = role_hook.action_config&.dig("prompt")
      parts = []
      parts << "Hook: #{role_hook.name}" if role_hook.name.present?
      parts << "Original task: #{task.title} (#{task.status})"
      parts << prompt if prompt.present?
      parts.join("\n\n")
    end

    def dispatch_webhook
      url = role_hook.action_config["url"]
      raise "Webhook URL not configured for hook #{role_hook.id}" unless url

      uri = URI.parse(url)
      headers = build_webhook_headers
      timeout = (role_hook.action_config["timeout"] || 30).to_i
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
      custom_headers = role_hook.action_config["headers"] || {}
      { "Content-Type" => "application/json" }.merge(custom_headers)
    end

    def build_webhook_payload
      {
        event: role_hook.lifecycle_event,
        hook_id: role_hook.id,
        hook_name: role_hook.name,
        task: {
          id: task.id,
          title: task.title,
          status: task.status,
          description: task.description,
          assignee_id: task.assignee_id,
          project_id: task.project_id,
          completed_at: task.completed_at&.iso8601
        },
        triggered_at: Time.current.iso8601
      }
    end

    def record_audit_event
      role_hook.record_audit_event!(
        actor: role_hook.role,
        action: "hook_executed",
        project: task.project,
        metadata: {
          hook_name: role_hook.name,
          action_type: role_hook.action_type,
          lifecycle_event: role_hook.lifecycle_event,
          task_id: task.id,
          task_title: task.title,
          execution_id: execution.id
        }
      )
    end
  end
end
