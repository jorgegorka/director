class Task < ApplicationRecord
  include Tenantable
  include Auditable

  belongs_to :creator, class_name: "User", optional: true
  belongs_to :assignee, class_name: "Agent", optional: true
  belongs_to :parent_task, class_name: "Task", optional: true

  has_many :subtasks, class_name: "Task", foreign_key: :parent_task_id, inverse_of: :parent_task, dependent: :destroy
  has_many :messages, dependent: :destroy

  enum :status, { open: 0, in_progress: 1, blocked: 2, completed: 3, cancelled: 4 }
  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }

  validates :title, presence: true
  validate :assignee_belongs_to_same_company
  validate :parent_task_belongs_to_same_company

  scope :active, -> { where.not(status: [ :completed, :cancelled ]) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :roots, -> { where(parent_task_id: nil) }

  before_save :set_completed_at

  private

  def assignee_belongs_to_same_company
    if assignee.present? && assignee.company_id != company_id
      errors.add(:assignee, "must belong to the same company")
    end
  end

  def parent_task_belongs_to_same_company
    if parent_task.present? && parent_task.company_id != company_id
      errors.add(:parent_task, "must belong to the same company")
    end
  end

  def set_completed_at
    if status_changed? && completed?
      self.completed_at = Time.current
    elsif status_changed? && !completed?
      self.completed_at = nil
    end
  end
end
