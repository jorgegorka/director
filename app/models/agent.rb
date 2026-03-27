class Agent < ApplicationRecord
  include Tenantable

  has_many :agent_capabilities, dependent: :destroy
  has_many :roles, dependent: :nullify
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :heartbeat_events, dependent: :destroy

  enum :adapter_type, { http: 0, process: 1, claude_local: 2 }
  enum :status, { idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5 }

  validates :name, presence: true,
                   uniqueness: { scope: :company_id, message: "already exists in this company" }
  validates :adapter_type, presence: true
  validates :adapter_config, presence: true
  validates :heartbeat_interval, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :validate_adapter_config_schema

  scope :active, -> { where.not(status: [ :terminated ]) }

  before_create :generate_api_token
  after_commit :sync_heartbeat_schedule, if: :heartbeat_config_changed?

  def regenerate_api_token!
    update!(api_token: self.class.generate_unique_api_token)
  end

  def self.generate_unique_api_token
    loop do
      token = SecureRandom.base58(24)
      break token unless exists?(api_token: token)
    end
  end

  def adapter_class
    AdapterRegistry.for(adapter_type)
  end

  def current_company_role
    roles.for_current_company.first
  end

  def subordinate_agents
    role = current_company_role
    return Agent.none unless role

    ids = role.children.where.not(agent_id: nil).pluck(:agent_id)
    Agent.where(id: ids).active
  end

  def manager_agent
    role = current_company_role
    return nil unless role

    parent_role = role.parent
    while parent_role
      return parent_role.agent if parent_role.agent.present?
      parent_role = parent_role.parent
    end
    nil
  end

  def online?
    idle? || running?
  end

  def offline?
    !online?
  end

  def heartbeat_scheduled?
    heartbeat_enabled? && heartbeat_interval.present?
  end

  def last_heartbeat_event
    heartbeat_events.reverse_chronological.first
  end

  private

  def generate_api_token
    self.api_token ||= self.class.generate_unique_api_token
  end

  def heartbeat_config_changed?
    saved_change_to_heartbeat_interval? || saved_change_to_heartbeat_enabled?
  end

  def sync_heartbeat_schedule
    HeartbeatScheduleManager.sync(self)
  end

  def validate_adapter_config_schema
    return if adapter_config.blank?
    required_keys = AdapterRegistry.required_config_keys(adapter_type)
    missing = required_keys - adapter_config.keys.map(&:to_s)
    if missing.any?
      errors.add(:adapter_config, "missing required keys: #{missing.join(', ')}")
    end
  end
end
