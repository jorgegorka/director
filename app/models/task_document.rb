class TaskDocument < ApplicationRecord
  belongs_to :task
  belongs_to :document

  validates :document_id, uniqueness: { scope: :task_id, message: "already linked to this task" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if task.present? && document.present? && document.company_id != task.company_id
      errors.add(:document, "must belong to the same company as the task")
    end
  end
end
