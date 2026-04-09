module Tasks
  module Reviewing
    extend ActiveSupport::Concern

    included do
      after_commit :trigger_pending_review_wake, on: :update, if: :just_entered_pending_review?
    end

    class ReviewError < StandardError; end

    def approve_by!(reviewer)
      raise ReviewError, "Only the creator can approve a task" unless creator_id == reviewer.id
      raise ReviewError, "Task is not pending review" unless pending_review?
      update!(status: :completed, reviewed_by: reviewer, reviewed_at: Time.current)
    end

    def reject_by!(reviewer, feedback:)
      raise ReviewError, "Only the creator can reject a task" unless creator_id == reviewer.id
      raise ReviewError, "Task is not pending review" unless pending_review?
      raise ReviewError, "Feedback is required when rejecting a task" if feedback.blank?
      transaction do
        update!(status: :open)
        messages.create!(author: reviewer, body: feedback, message_type: :comment)
      end
    end

    private

    def just_entered_pending_review?
      saved_change_to_status? && pending_review?
    end

    def trigger_pending_review_wake
      return unless creator

      trigger_role_wake(
        role: creator,
        trigger_type: :task_pending_review,
        trigger_source: "Task##{id}",
        context: { task_id: id, task_title: title, assignee_role_title: assignee&.title }
      )
    end
  end
end
