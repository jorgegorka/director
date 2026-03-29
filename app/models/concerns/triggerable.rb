module Triggerable
  extend ActiveSupport::Concern

  private

  def trigger_role_wake(role:, trigger_type:, trigger_source:, context: {})
    return if role.nil? || role.terminated?

    WakeRoleService.call(
      role: role,
      trigger_type: trigger_type,
      trigger_source: trigger_source,
      context: context
    )
  end

  # Uses substring matching to support multi-word role titles (e.g. "@API Bot")
  def detect_mentions(text, company)
    return [] if text.blank? || company.nil?
    return [] unless text.include?("@")

    text_downcased = text.downcase
    company.roles.active.select do |role|
      text_downcased.include?("@#{role.title.downcase}")
    end
  end
end
