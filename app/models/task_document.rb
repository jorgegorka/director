class TaskDocument < ApplicationRecord
  belongs_to :task
  belongs_to :document

  validates :document_id, uniqueness: { scope: :task_id, message: "already linked to this task" }
end
