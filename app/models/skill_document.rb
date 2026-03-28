class SkillDocument < ApplicationRecord
  belongs_to :skill
  belongs_to :document

  validates :document_id, uniqueness: { scope: :skill_id, message: "already linked to this skill" }
end
