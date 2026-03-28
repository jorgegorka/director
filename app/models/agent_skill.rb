class AgentSkill < ApplicationRecord
  belongs_to :agent
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :agent_id, message: "already assigned to this agent" }
  validate :same_company

  private

  def same_company
    return unless agent && skill
    unless agent.company_id == skill.company_id
      errors.add(:skill, "must belong to the same company as the agent")
    end
  end
end
