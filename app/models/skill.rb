class Skill < ApplicationRecord
  include Tenantable

  has_many :role_skills, dependent: :destroy, inverse_of: :skill
  has_many :roles, through: :role_skills

  has_many :skill_documents, dependent: :destroy, inverse_of: :skill
  has_many :documents, through: :skill_documents

  validates :key, presence: true,
                  uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :markdown, presence: true

  scope :by_category, ->(cat) { where(category: cat) }
  scope :builtin, -> { where(builtin: true) }
  scope :custom, -> { where(builtin: false) }
end
