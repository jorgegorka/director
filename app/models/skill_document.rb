class SkillDocument < ApplicationRecord
  belongs_to :skill
  belongs_to :document

  validates :document_id, uniqueness: { scope: :skill_id, message: "already linked to this skill" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if skill.present? && document.present? && document.company_id != skill.company_id
      errors.add(:document, "must belong to the same company as the skill")
    end
  end
end
