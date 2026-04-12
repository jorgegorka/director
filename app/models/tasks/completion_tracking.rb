module Tasks
  module CompletionTracking
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_task_alignment_evaluation, on: [ :create, :update ]
      after_commit :recalculate_parent_task_completion, on: [ :create, :update, :destroy ]
      after_commit :sync_leaf_completion_percentage, on: :update
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

    def enqueue_task_alignment_evaluation
      return unless saved_change_to_status?
      return unless completed?
      return if parent_task_id.nil?
      return if creator&.agent_configured?

      EvaluateTaskAlignmentJob.perform_later(id)
    end

    def recalculate_parent_task_completion
      return unless saved_change_to_status? || saved_change_to_parent_task_id? || previously_new_record? || destroyed?

      affected_id = parent_task_id || parent_task_id_before_last_save
      return unless affected_id

      RecalculateTaskCompletionJob.perform_later(affected_id)
    end

    def sync_leaf_completion_percentage
      return unless saved_change_to_status?
      return if subtasks.exists?

      new_pct = completed? ? 100 : 0
      update_column(:completion_percentage, new_pct) unless completion_percentage == new_pct
    end
  end
end
