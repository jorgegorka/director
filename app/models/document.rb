class Document < ApplicationRecord
  include Tenantable
  include Auditable
  include Chronological

  belongs_to :author, polymorphic: true
  belongs_to :last_editor, polymorphic: true, optional: true

  has_many :skill_documents, dependent: :destroy
  has_many :skills, through: :skill_documents

  has_many :agent_documents, dependent: :destroy
  has_many :agents, through: :agent_documents

  has_many :task_documents, dependent: :destroy
  has_many :tasks, through: :task_documents

  has_many :document_taggings, dependent: :destroy
  has_many :tags, through: :document_taggings, source: :document_tag

  validates :title, presence: true
  validates :body, presence: true

  scope :tagged_with, ->(tag_name) {
    joins(:tags).where(document_tags: { name: tag_name })
  }
  scope :by_author, ->(author) {
    where(author: author)
  }
end
