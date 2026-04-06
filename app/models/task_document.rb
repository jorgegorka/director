class TaskDocument < ApplicationRecord
  belongs_to :task
  belongs_to :document

  validates :document_id, uniqueness: { scope: :task_id, message: "already linked to this task" }
  validate :document_belongs_to_same_project

  private

  def document_belongs_to_same_project
    if task.present? && document.present? && document.project_id != task.project_id
      errors.add(:document, "must belong to the same project as the task")
    end
  end
end
