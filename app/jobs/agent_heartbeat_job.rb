class AgentHeartbeatJob < ApplicationJob
  queue_as :default

  def perform(agent_id)
    agent = Agent.find_by(id: agent_id)
    return unless agent
    return unless agent.heartbeat_scheduled?
    return if agent.terminated?

    WakeAgentService.call(
      agent: agent,
      trigger_type: :scheduled,
      trigger_source: "schedule"
    )
  end
end
