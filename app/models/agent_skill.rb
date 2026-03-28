class AgentSkill < ApplicationRecord
  belongs_to :agent
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :agent_id, message: "already assigned to this agent" }
  validate :skill_belongs_to_same_company

  private

  def skill_belongs_to_same_company
    if agent.present? && skill.present? && skill.company_id != agent.company_id
      errors.add(:skill, "must belong to the same company as the agent")
    end
  end
end
