class Goal < ApplicationRecord
  include Tenantable
  include Auditable
  include Triggerable

  belongs_to :role, optional: true

  has_many :tasks, dependent: :nullify
  has_many :goal_evaluations, dependent: :destroy

  validates :title, presence: true,
                    uniqueness: { scope: :project_id }
  validates :completion_percentage, numericality: { only_integer: true, in: 0..100 }
  validate :role_belongs_to_same_project

  scope :ordered, -> { order(:position, :title) }

  after_commit :trigger_goal_assignment_wake, on: [ :create, :update ], if: :role_just_assigned?
  after_create_commit :audit_created
  after_update_commit :audit_updated
  before_destroy :audit_destroyed

  def finalized?
    completion_percentage == 100
  end

  def recalculate_completion!
    counts = tasks.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(CASE WHEN status = #{Task.statuses[:completed]} THEN 1 END)")
    )
    total, completed = counts
    percentage = total > 0 ? ((completed.to_f / total) * 100).round : 0

    update_column(:completion_percentage, percentage) unless completion_percentage == percentage
  end

  private

  def role_belongs_to_same_project
    if role.present? && role.project_id != project_id
      errors.add(:role, "must belong to the same project")
    end
  end

  def role_just_assigned?
    return role_id.present? if previously_new_record?

    saved_change_to_role_id? && role_id.present?
  end

  def trigger_goal_assignment_wake
    return unless role&.online?
    return if finalized?

    trigger_role_wake(
      role: role,
      trigger_type: :goal_assigned,
      trigger_source: "Goal##{id}",
      context: { goal_id: id, goal_title: title, goal_description: description }
    )
  end

  def audit_created
    actor = audit_actor
    return unless actor

    record_audit_event!(actor: actor, action: "created", metadata: { title: title })
  end

  def audit_updated
    tracked = saved_changes.slice("title", "description", "role_id", "completion_percentage")
    return if tracked.empty?
    actor = audit_actor
    return unless actor

    changes = tracked.transform_values { |v| { from: v[0], to: v[1] } }
    record_audit_event!(actor: actor, action: "updated", metadata: changes)
  end
end
