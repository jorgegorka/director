class HeartbeatEvent < ApplicationRecord
  include Chronological

  belongs_to :role

  enum :trigger_type, { scheduled: 0, task_assigned: 1, mention: 2, hook_triggered: 3, review_validation: 4, goal_evaluation_failed: 5, question_asked: 6, question_answered: 7, manual: 8, goal_assigned: 9, task_pending_review: 10 }
  enum :status, { queued: 0, delivered: 1, failed: 2 }

  validates :trigger_type, presence: true
  validates :status, presence: true
  scope :by_trigger, ->(type) { where(trigger_type: type) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }
  scope :for_role, ->(role) { where(role: role) }

  def mark_delivered!(response: {})
    update!(
      status: :delivered,
      delivered_at: Time.current,
      response_payload: response
    )
  end

  def mark_failed!(error_message:)
    update!(
      status: :failed,
      metadata: metadata.merge("error" => error_message)
    )
  end
end
