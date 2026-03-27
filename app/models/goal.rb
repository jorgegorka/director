class Goal < ApplicationRecord
  include Tenantable
  include TreeHierarchy

  has_many :children, class_name: "Goal", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :tasks, dependent: :nullify

  validates :title, presence: true,
                    uniqueness: { scope: [ :company_id, :parent_id ], message: "already exists under this parent" }

  scope :ordered, -> { order(:position, :title) }

  def mission?
    root?
  end

  def ancestry_chain
    (ancestors.reverse << self)
  end

  def progress
    all_task_ids = subtree_task_ids
    return 0.0 if all_task_ids.empty?

    total = all_task_ids.size
    completed = Task.where(id: all_task_ids, status: :completed).count
    completed.to_f / total
  end

  def progress_percentage
    (progress * 100).round
  end

  private

  def subtree_task_ids
    goal_ids = [ id ] + descendants.map(&:id)
    Task.where(goal_id: goal_ids).pluck(:id)
  end
end
