class Message < ApplicationRecord
  include Triggerable
  include Chronological

  belongs_to :task
  belongs_to :author, polymorphic: true
  belongs_to :parent, class_name: "Message", optional: true

  has_many :replies, class_name: "Message", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  enum :message_type, { comment: 0, question: 1, answer: 2 }

  validates :body, presence: true
  validate :parent_belongs_to_same_task

  scope :roots, -> { where(parent_id: nil) }

  after_commit :trigger_mention_wake, on: :create
  after_commit :trigger_answer_wake, on: :create

  private

  def parent_belongs_to_same_task
    if parent.present? && parent.task_id != task_id
      errors.add(:parent, "must belong to the same task")
    end
  end

  def trigger_mention_wake
    project = task&.project
    return unless project

    mentioned_roles = detect_mentions(body, project)
    mentioned_roles.each do |mentioned_role|
      next if mentioned_role == author

      trigger_role_wake(
        role: mentioned_role,
        trigger_type: :mention,
        trigger_source: "Message##{id}",
        context: {
          message_id: id,
          task_id: task_id,
          mentioned_by: author_type == "User" ? "user" : "role"
        }
      )
    end
  end

  def trigger_answer_wake
    return unless answer? && parent&.question?
    return unless parent.author_type == "Role"
    return if parent.author == author

    trigger_role_wake(
      role: parent.author,
      trigger_type: :question_answered,
      trigger_source: "Message##{id}",
      context: {
        answer_message_id: id,
        question_message_id: parent.id,
        task_id: task_id,
        answered_by: author_type == "User" ? "user" : "role"
      }
    )
  end
end
