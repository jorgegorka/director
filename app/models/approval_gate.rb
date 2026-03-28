class ApprovalGate < ApplicationRecord
  include Enableable

  GATABLE_ACTIONS = %w[
    task_creation
    task_delegation
    budget_spend
    status_change
    escalation
  ].freeze

  belongs_to :agent

  validates :action_type, presence: true,
                          inclusion: { in: GATABLE_ACTIONS, message: "%{value} is not a valid gatable action" },
                          uniqueness: { scope: :agent_id, message: "gate already exists for this agent" }

  scope :for_action, ->(action) { where(action_type: action) }
end
