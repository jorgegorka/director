class Goal < ApplicationRecord
  include Tenantable

  belongs_to :parent, class_name: "Goal", optional: true
  has_many :children, class_name: "Goal", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :tasks, dependent: :nullify

  validates :title, presence: true,
                    uniqueness: { scope: [ :company_id, :parent_id ], message: "already exists under this parent" }
  validate :parent_belongs_to_same_company
  validate :parent_is_not_self
  validate :parent_is_not_descendant

  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :title) }

  # Tree traversal (same pattern as Role model)
  def ancestors
    result = []
    current = parent
    while current
      result << current
      current = current.parent
    end
    result
  end

  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
  end

  def root?
    parent_id.nil?
  end

  def depth
    ancestors.size
  end

  def mission?
    root?
  end

  # Full ancestry chain as breadcrumb: [mission, ..., self]
  def ancestry_chain
    (ancestors.reverse << self)
  end

  # --- Progress roll-up ---
  # Returns a float 0.0..1.0 representing completion percentage.
  # For leaf goals (no children): completed_tasks / total_tasks on this goal.
  # For branch goals (has children): aggregates all tasks in this subtree.
  # Returns 0.0 if no tasks exist in the subtree.
  def progress
    all_task_ids = subtree_task_ids
    return 0.0 if all_task_ids.empty?

    total = all_task_ids.size
    completed = Task.where(id: all_task_ids, status: :completed).count
    completed.to_f / total
  end

  # Returns integer percentage 0-100 for display convenience
  def progress_percentage
    (progress * 100).round
  end

  private

  # Collect task IDs for this goal and all descendant goals.
  # Uses a single query per level to avoid N+1.
  def subtree_task_ids
    goal_ids = [ id ] + descendants.map(&:id)
    Task.where(goal_id: goal_ids).pluck(:id)
  end

  def parent_belongs_to_same_company
    if parent.present? && parent.company_id != company_id
      errors.add(:parent, "must belong to the same company")
    end
  end

  def parent_is_not_self
    if parent_id.present? && parent_id == id
      errors.add(:parent, "cannot be the goal itself")
    end
  end

  def parent_is_not_descendant
    if parent_id.present? && id.present? && descendants.map(&:id).include?(parent_id)
      errors.add(:parent, "cannot be a descendant of this goal")
    end
  end
end
