class AgentDocument < ApplicationRecord
  belongs_to :agent
  belongs_to :document

  validates :document_id, uniqueness: { scope: :agent_id, message: "already linked to this agent" }
end
