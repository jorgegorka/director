module Tasks
  module CompletionTracking
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_goal_evaluation, on: [ :create, :update ]
      after_commit :recalculate_goal_completion, on: [ :create, :update, :destroy ]
      after_commit :recalculate_parent_task_completion, on: [ :create, :update, :destroy ]
    end

    def recalculate_completion!
      completed_status = Task.statuses[:completed]
      total, done = subtasks.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(CASE WHEN status = #{completed_status} THEN 1 END)")
      )
      pct = total > 0 ? ((done.to_f / total) * 100).round : 0
      update_column(:completion_percentage, pct) unless completion_percentage == pct

      auto_transition_on_subtasks_completed! if pct == 100 && total > 0
    end

    private

    def auto_transition_on_subtasks_completed!
      return unless in_progress? || open?

      if parent_task_id.present?
        update!(status: :pending_review)
      else
        update!(status: :completed)
      end
    end

    def enqueue_goal_evaluation
      return unless saved_change_to_status?
      return unless completed?
      return unless goal_id.present?
      return if creator&.agent_configured?

      EvaluateGoalAlignmentJob.perform_later(id)
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
end
