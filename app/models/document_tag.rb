class DocumentTag < ApplicationRecord
  include Tenantable

  has_many :document_taggings, dependent: :destroy
  has_many :documents, through: :document_taggings

  validates :name, presence: true, uniqueness: { scope: :project_id }
end
