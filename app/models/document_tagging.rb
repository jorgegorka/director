class DocumentTagging < ApplicationRecord
  belongs_to :document
  belongs_to :document_tag

  validates :document_tag_id, uniqueness: { scope: :document_id, message: "already applied to this document" }
end
