class Skill < ApplicationRecord
  include Tenantable

  has_many :agent_skills, dependent: :destroy, inverse_of: :skill
  has_many :agents, through: :agent_skills

  validates :key, presence: true,
                  uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :markdown, presence: true

  scope :by_category, ->(cat) { where(category: cat) }
  scope :builtin, -> { where(builtin: true) }
  scope :custom, -> { where(builtin: false) }
end
