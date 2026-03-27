class AgentCapability < ApplicationRecord
  belongs_to :agent

  validates :name, presence: true,
                   uniqueness: { scope: :agent_id, message: "already declared for this agent" }

  scope :by_name, -> { order(:name) }
end
