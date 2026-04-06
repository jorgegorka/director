class RoleSkill < ApplicationRecord
  belongs_to :role
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :role_id, message: "already assigned to this role" }
  validate :skill_belongs_to_same_project

  private

  def skill_belongs_to_same_project
    if role.present? && skill.present? && skill.project_id != role.project_id
      errors.add(:skill, "must belong to the same project as the role")
    end
  end
end
