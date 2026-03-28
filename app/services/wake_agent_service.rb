class WakeAgentService
  attr_reader :agent, :trigger_type, :trigger_source, :context

  def initialize(agent:, trigger_type:, trigger_source: nil, context: {})
    @agent = agent
    @trigger_type = trigger_type.to_s
    @trigger_source = trigger_source
    @context = context
  end

  def call
    return nil if agent.terminated?

    event = create_event
    deliver(event)
    update_agent_heartbeat_timestamp
    event
  end

  def self.call(**args)
    new(**args).call
  end

  private

  def create_event
    agent.heartbeat_events.create!(
      trigger_type: trigger_type,
      trigger_source: trigger_source,
      status: initial_status,
      request_payload: build_request_payload
    )
  end

  def initial_status
    agent.http? ? :delivered : :queued
  end

  def deliver(event)
    if agent.http?
      deliver_http(event)
    else
      event
    end

    dispatch_execution(event)
  rescue StandardError => e
    event.mark_failed!(error_message: e.message)
    event
  end

  # TODO: POST to agent.adapter_config["url"] when adapter execution is built
  def deliver_http(event)
    event.mark_delivered!(response: { status: "acknowledged" })
    event
  end

  def dispatch_execution(event)
    agent_run = agent.agent_runs.create!(
      task: find_task_from_context,
      company_id: agent.company_id,
      status: :queued,
      trigger_type: trigger_type
    )

    ExecuteAgentJob.perform_later(agent_run.id)
    agent_run
  end

  def find_task_from_context
    task_id = context[:task_id] || context["task_id"]
    return nil unless task_id
    Task.find_by(id: task_id)
  end

  def build_request_payload
    {
      trigger: trigger_type,
      agent_id: agent.id,
      agent_name: agent.name,
      company_id: agent.company_id,
      triggered_at: Time.current.iso8601
    }.merge(context)
  end

  def update_agent_heartbeat_timestamp
    agent.update_column(:last_heartbeat_at, Time.current)
  end
end
