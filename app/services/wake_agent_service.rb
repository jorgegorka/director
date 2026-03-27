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
    # HTTP agents get immediate delivery attempt; process/claude_local agents get queued events
    agent.http? ? :delivered : :queued
  end

  def deliver(event)
    if agent.http?
      deliver_http(event)
    else
      # Process and claude_local agents poll for queued events
      # Event is already created with status: queued -- they will pick it up
      event
    end
  rescue StandardError => e
    event.mark_failed!(error_message: e.message)
    event
  end

  def deliver_http(event)
    # For now, mark as delivered. Actual HTTP POST will be implemented
    # when the adapter execution system is fully built.
    # The event is created with status: delivered for HTTP agents.
    # In a full implementation, this would POST to agent.adapter_config["url"].
    event.mark_delivered!(response: { status: "acknowledged" })
    event
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
