class AgentDocument < ApplicationRecord
  belongs_to :agent
  belongs_to :document

  validates :document_id, uniqueness: { scope: :agent_id, message: "already linked to this agent" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if agent.present? && document.present? && document.company_id != agent.company_id
      errors.add(:document, "must belong to the same company as the agent")
    end
  end
end
