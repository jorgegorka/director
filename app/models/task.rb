class Task < ApplicationRecord
  include Tenantable
  include Auditable
  include Triggerable
  include Hookable

  belongs_to :creator, class_name: "Role", optional: true
  belongs_to :assignee, class_name: "Role", optional: true
  belongs_to :reviewed_by, class_name: "Role", optional: true
  belongs_to :parent_task, class_name: "Task", optional: true
  belongs_to :goal, optional: true

  has_many :subtasks, class_name: "Task", foreign_key: :parent_task_id, inverse_of: :parent_task, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :hook_executions, dependent: :destroy
  has_many :role_runs, dependent: :nullify
  has_many :goal_evaluations, dependent: :destroy

  has_many :task_documents, dependent: :destroy, inverse_of: :task
  has_many :documents, through: :task_documents

  enum :status, { open: 0, in_progress: 1, blocked: 2, completed: 3, cancelled: 4, pending_review: 5 }
  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }

  validates :title, presence: true
  validates :cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :completion_percentage, numericality: { only_integer: true, in: 0..100 }
  validate :assignee_belongs_to_same_company
  validate :creator_belongs_to_same_company
  validate :parent_task_belongs_to_same_company
  validate :goal_belongs_to_same_company
  validate :assignee_within_delegation_scope

  scope :active, -> { where.not(status: [ :completed, :cancelled ]) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :roots, -> { where(parent_task_id: nil) }

  before_save :set_completed_at
  after_commit :trigger_assignment_wake, on: [ :create, :update ], if: :agent_just_assigned?
  after_commit :trigger_pending_review_wake, on: :update, if: :just_entered_pending_review?
  after_commit :broadcast_kanban_update, on: [ :create, :update ]
  after_commit :broadcast_kanban_remove, on: :destroy
  after_commit :enqueue_hooks_for_transition, on: [ :create, :update ]
  after_commit :enqueue_validation_feedback, on: [ :create, :update ]
  after_commit :enqueue_goal_evaluation, on: [ :create, :update ]
  after_commit :recalculate_goal_completion, on: [ :create, :update, :destroy ]
  after_commit :recalculate_parent_task_completion, on: [ :create, :update, :destroy ]

  def cost_in_dollars
    return nil unless cost_cents
    cost_cents / 100.0
  end

  def recalculate_completion!
    total, done = subtasks.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(CASE WHEN status = #{Task.statuses[:completed]} THEN 1 END)")
    )
    pct = total > 0 ? ((done.to_f / total) * 100).round : 0
    update_column(:completion_percentage, pct) unless completion_percentage == pct
  end

  private

  def broadcast_kanban_update
    return unless company_id
    Turbo::StreamsChannel.broadcast_remove_to(
      "dashboard_company_#{company_id}",
      target: "kanban-task-#{id}"
    )
    Turbo::StreamsChannel.broadcast_append_to(
      "dashboard_company_#{company_id}",
      target: "kanban-column-body-#{status}",
      partial: "dashboard/kanban_card",
      locals: { task: self }
    )
  end

  def broadcast_kanban_remove
    return unless company_id
    Turbo::StreamsChannel.broadcast_remove_to(
      "dashboard_company_#{company_id}",
      target: "kanban-task-#{id}"
    )
  end

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

  def goal_belongs_to_same_company
    if goal.present? && goal.company_id != company_id
      errors.add(:goal, "must belong to the same company")
    end
  end

  def set_completed_at
    if status_changed? && completed?
      self.completed_at = Time.current
    elsif status_changed? && !completed?
      self.completed_at = nil
    end
  end

  def agent_just_assigned?
    return assignee_id.present? if previously_new_record?

    saved_change_to_assignee_id? && assignee_id.present?
  end

  def trigger_assignment_wake
    return unless assignee

    trigger_role_wake(
      role: assignee,
      trigger_type: :task_assigned,
      trigger_source: "Task##{id}",
      context: { task_id: id, task_title: title }
    )
  end

  def enqueue_goal_evaluation
    return unless saved_change_to_status?
    return unless completed?
    return unless goal_id.present?
    return if creator&.agent_configured?

    EvaluateGoalAlignmentJob.perform_later(id)
  end

  def creator_belongs_to_same_company
    if creator.present? && creator.company_id != company_id
      errors.add(:creator, "must belong to the same company")
    end
  end

  def assignee_within_delegation_scope
    return unless creator.present? && assignee.present?
    return if creator_id == assignee_id
    return unless new_record? || creator_id_changed? || assignee_id_changed?

    is_subordinate = creator.descendant_ids.include?(assignee_id)
    is_sibling = creator.parent_id.present? && assignee.parent_id == creator.parent_id

    unless is_subordinate || is_sibling
      errors.add(:assignee, "must be a subordinate or sibling of the creator role")
    end
  end

  def just_entered_pending_review?
    saved_change_to_status? && pending_review?
  end

  def trigger_pending_review_wake
    return unless creator&.online?

    trigger_role_wake(
      role: creator,
      trigger_type: :task_pending_review,
      trigger_source: "Task##{id}",
      context: { task_id: id, task_title: title, assignee_role_title: assignee&.title }
    )
  end

  def recalculate_goal_completion
    return unless saved_change_to_status? || saved_change_to_goal_id? || previously_new_record? || destroyed?

    affected_goal_id = goal_id || goal_id_before_last_save
    return unless affected_goal_id

    RecalculateGoalCompletionJob.perform_later(affected_goal_id)
  end

  def recalculate_parent_task_completion
    return unless saved_change_to_status? || saved_change_to_parent_task_id? || previously_new_record? || destroyed?

    affected_id = parent_task_id || parent_task_id_before_last_save
    return unless affected_id

    RecalculateTaskCompletionJob.perform_later(affected_id)
  end
end
