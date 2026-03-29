class RoleSkill < ApplicationRecord
  belongs_to :role
  belongs_to :skill

  validates :skill_id, uniqueness: { scope: :role_id, message: "already assigned to this role" }
  validate :skill_belongs_to_same_company

  private

  def skill_belongs_to_same_company
    if role.present? && skill.present? && skill.company_id != role.company_id
      errors.add(:skill, "must belong to the same company as the role")
    end
  end
end
