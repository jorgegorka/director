class RoleHook < ApplicationRecord
  include Tenantable
  include Auditable
  include ConfigVersioned
  include Enableable

  AFTER_TASK_START = "after_task_start".freeze
  AFTER_TASK_COMPLETE = "after_task_complete".freeze
  LIFECYCLE_EVENTS = [ AFTER_TASK_START, AFTER_TASK_COMPLETE ].freeze

  ACTION_CONFIG_KEYS = {
    "trigger_agent" => %w[target_role_id target_agent_id prompt],
    "webhook" => %w[url headers timeout]
  }.freeze

  belongs_to :role
  has_many :hook_executions, dependent: :destroy

  enum :action_type, { trigger_agent: 0, webhook: 1 }

  validates :lifecycle_event, presence: true,
                              inclusion: { in: LIFECYCLE_EVENTS, message: "%{value} is not a valid lifecycle event" }
  validates :action_type, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_action_config_schema

  before_validation :filter_action_config, if: :action_config_changed?

  scope :for_event, ->(event) { where(lifecycle_event: event) }
  scope :ordered, -> { order(:position, :created_at) }

  def target_role
    return @target_role if defined?(@target_role)
    @target_role = if trigger_agent?
      target_id = action_config&.dig("target_role_id") || action_config&.dig("target_agent_id")
      target_id && role.project.roles.find_by(id: target_id)
    end
  end

  def governance_attributes
    %w[lifecycle_event action_type action_config enabled position name]
  end

  private

  def filter_action_config
    return if action_config.blank? || action_type.blank?
    allowed = ACTION_CONFIG_KEYS.fetch(action_type, [])
    self.action_config = action_config.stringify_keys.slice(*allowed)
  end

  def validate_action_config_schema
    return if action_config.blank?

    if trigger_agent?
      unless action_config.key?("target_role_id") || action_config.key?("target_agent_id")
        errors.add(:action_config, "must include target_role_id for trigger_agent hooks")
      end
    elsif webhook?
      unless action_config.key?("url")
        errors.add(:action_config, "must include url for webhook hooks")
      end
    end
  end
end
