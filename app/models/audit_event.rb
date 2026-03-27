class AuditEvent < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :actor, polymorphic: true
  belongs_to :company, optional: true

  validates :action, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :for_action, ->(action_name) { where(action: action_name) }
  scope :for_company, ->(company) { where(company: company) }
  scope :for_actor_type, ->(type) { where(actor_type: type) }
  scope :for_date_range, ->(start_date, end_date) { where(created_at: start_date.beginning_of_day..end_date.end_of_day) }

  # Governance-specific action types
  GOVERNANCE_ACTIONS = %w[
    gate_approval
    gate_rejection
    emergency_stop
    emergency_resume
    agent_paused
    agent_resumed
    agent_terminated
    config_rollback
    cost_recorded
  ].freeze

  # Immutability: prevent updates to persisted records
  def readonly?
    persisted?
  end

  def governance_action?
    GOVERNANCE_ACTIONS.include?(action)
  end
end
