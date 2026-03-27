class AgentCapability < ApplicationRecord
  belongs_to :agent

  validates :name, presence: true
  validates :name, uniqueness: { scope: :agent_id, message: "already declared for this agent" }

  scope :by_name, -> { order(:name) }
end
