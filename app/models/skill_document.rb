class SkillDocument < ApplicationRecord
  belongs_to :skill
  belongs_to :document

  validates :document_id, uniqueness: { scope: :skill_id, message: "already linked to this skill" }
  validate :document_belongs_to_same_project

  private

  def document_belongs_to_same_project
    if skill.present? && document.present? && document.project_id != skill.project_id
      errors.add(:document, "must belong to the same project as the skill")
    end
  end
end
