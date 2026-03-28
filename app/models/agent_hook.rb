class AgentHook < ApplicationRecord
  include Tenantable
  include Auditable
  include ConfigVersioned

  LIFECYCLE_EVENTS = %w[
    after_task_start
    after_task_complete
  ].freeze

  belongs_to :agent
  has_many :hook_executions, dependent: :destroy

  enum :action_type, { trigger_agent: 0, webhook: 1 }

  validates :lifecycle_event, presence: true,
                              inclusion: { in: LIFECYCLE_EVENTS, message: "%{value} is not a valid lifecycle event" }
  validates :action_type, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_action_config_schema

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :for_event, ->(event) { where(lifecycle_event: event) }
  scope :ordered, -> { order(:position, :created_at) }

  def target_agent
    return nil unless trigger_agent?
    target_id = action_config&.dig("target_agent_id")
    return nil unless target_id
    Agent.find_by(id: target_id)
  end

  def governance_attributes
    %w[lifecycle_event action_type action_config enabled position name]
  end

  private

  def validate_action_config_schema
    return if action_config.blank?

    if trigger_agent?
      unless action_config.key?("target_agent_id")
        errors.add(:action_config, "must include target_agent_id for trigger_agent hooks")
      end
    elsif webhook?
      unless action_config.key?("url")
        errors.add(:action_config, "must include url for webhook hooks")
      end
    end
  end
end
