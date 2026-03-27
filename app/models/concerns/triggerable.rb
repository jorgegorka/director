module Triggerable
  extend ActiveSupport::Concern

  private

  def trigger_agent_wake(agent:, trigger_type:, trigger_source:, context: {})
    return if agent.nil? || agent.terminated?

    WakeAgentService.call(
      agent: agent,
      trigger_type: trigger_type,
      trigger_source: trigger_source,
      context: context
    )
  end

  # Uses substring matching to support multi-word agent names (e.g. "@API Bot")
  def detect_mentions(text, company)
    return [] if text.blank? || company.nil?

    text_downcased = text.downcase
    company.agents.active.select do |agent|
      text_downcased.include?("@#{agent.name.downcase}")
    end
  end
end
