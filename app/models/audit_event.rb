class AuditEvent < ApplicationRecord
  include Chronological

  belongs_to :auditable, polymorphic: true
  belongs_to :actor, polymorphic: true
  belongs_to :company, optional: true

  validates :action, presence: true

  after_create_commit :broadcast_activity_event
  scope :for_action, ->(action_name) { where(action: action_name) }
  scope :for_company, ->(company) { where(company: company) }
  scope :for_actor_type, ->(type) { where(actor_type: type) }
  scope :for_date_range, ->(start_date, end_date) { where(created_at: start_date.beginning_of_day..end_date.end_of_day) }

  # Governance-specific action types
  GOVERNANCE_ACTIONS = %w[
    gate_approval
    gate_rejection
    gate_blocked
    emergency_stop
    emergency_resume
    agent_paused
    agent_resumed
    agent_terminated
    config_rollback
    cost_recorded
    hook_executed
  ].freeze

  # Immutability: prevent updates to persisted records
  def readonly?
    persisted?
  end

  def governance_action?
    GOVERNANCE_ACTIONS.include?(action)
  end

  private

  def broadcast_activity_event
    return unless company_id
    Turbo::StreamsChannel.broadcast_prepend_to(
      "dashboard_company_#{company_id}",
      target: "activity-timeline",
      partial: "dashboard/activity_event",
      locals: { event: self }
    )
  end
end
