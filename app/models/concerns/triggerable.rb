module Triggerable
  extend ActiveSupport::Concern

  private

  # Enqueue a wake event for the given agent.
  # Called from model-specific after_commit callbacks.
  def trigger_agent_wake(agent:, trigger_type:, trigger_source:, context: {})
    return if agent.nil? || agent.terminated?

    WakeAgentService.call(
      agent: agent,
      trigger_type: trigger_type,
      trigger_source: trigger_source,
      context: context
    )
  end

  # Detect @mentions in text. Returns array of Agent records.
  # Matches @agent_name patterns (case-insensitive).
  # Agent names are matched against agents in the same company.
  # Uses direct string matching to handle multi-word agent names.
  def detect_mentions(text, company)
    return [] if text.blank? || company.nil?

    downcased = text.downcase
    company.agents.active.select do |agent|
      downcased.include?("@#{agent.name.downcase}")
    end
  end
end
