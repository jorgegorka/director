class Goal < ApplicationRecord
  include Tenantable
  include TreeHierarchy
  include Triggerable

  belongs_to :role, optional: true

  has_many :children, class_name: "Goal", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :tasks, dependent: :nullify
  has_many :goal_evaluations, dependent: :destroy

  validates :title, presence: true,
                    uniqueness: { scope: [ :company_id, :parent_id ], message: "already exists under this parent" }
  validate :role_belongs_to_same_company

  scope :ordered, -> { order(:position, :title) }

  after_commit :trigger_goal_assignment_wake, on: [ :create, :update ], if: :role_just_assigned?

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

  def role_belongs_to_same_company
    if role.present? && role.company_id != company_id
      errors.add(:role, "must belong to the same company")
    end
  end

  def subtree_task_ids
    goal_ids = [ id ] + descendant_ids
    Task.where(goal_id: goal_ids).pluck(:id)
  end

  def role_just_assigned?
    return role_id.present? if previously_new_record?

    saved_change_to_role_id? && role_id.present?
  end

  def trigger_goal_assignment_wake
    return unless role&.online?

    trigger_role_wake(
      role: role,
      trigger_type: :goal_assigned,
      trigger_source: "Goal##{id}",
      context: { goal_id: id, goal_title: title, goal_description: description }
    )
  end
end
