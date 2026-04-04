module Triggerable
  extend ActiveSupport::Concern

  private

  def trigger_role_wake(role:, trigger_type:, trigger_source:, context: {})
    return if role.nil? || role.terminated?

    Roles::Waking.call(
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
    matched_ids = company.roles.active.pluck(:id, :title).filter_map do |id, title|
      id if text_downcased.include?("@#{title.downcase}")
    end

    matched_ids.any? ? company.roles.where(id: matched_ids).to_a : []
  end
end
