module Tasks
  module Assignment
    extend ActiveSupport::Concern

    included do
      after_commit :trigger_assignment_wake, on: [ :create, :update ], if: :agent_just_assigned?

      validate :assignee_within_delegation_scope
    end

    private

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
  end
end
