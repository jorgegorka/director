class RoleDocument < ApplicationRecord
  belongs_to :role
  belongs_to :document

  validates :document_id, uniqueness: { scope: :role_id, message: "already linked to this role" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if role.present? && document.present? && document.company_id != role.company_id
      errors.add(:document, "must belong to the same company as the role")
    end
  end
end
