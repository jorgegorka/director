class Agent < ApplicationRecord
  include Tenantable

  has_many :agent_capabilities, dependent: :destroy
  has_many :roles, dependent: :nullify

  enum :adapter_type, { http: 0, process: 1, claude_local: 2 }
  enum :status, { idle: 0, running: 1, paused: 2, error: 3, terminated: 4, pending_approval: 5 }

  validates :name, presence: true
  validates :name, uniqueness: { scope: :company_id, message: "already exists in this company" }
  validates :adapter_type, presence: true
  validates :adapter_config, presence: true
  validate :validate_adapter_config_schema

  scope :active, -> { where.not(status: [ :terminated ]) }

  def adapter
    AdapterRegistry.for(adapter_type)
  end

  def online?
    idle? || running?
  end

  def offline?
    !online?
  end

  private

  def validate_adapter_config_schema
    return if adapter_config.blank?
    required_keys = AdapterRegistry.required_config_keys(adapter_type)
    missing = required_keys - adapter_config.keys.map(&:to_s)
    if missing.any?
      errors.add(:adapter_config, "missing required keys: #{missing.join(', ')}")
    end
  end
end
