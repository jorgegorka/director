class Message < ApplicationRecord
  include Triggerable
  include Chronological

  belongs_to :task
  belongs_to :author, polymorphic: true
  belongs_to :parent, class_name: "Message", optional: true

  has_many :replies, class_name: "Message", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  validates :body, presence: true
  validate :parent_belongs_to_same_task

  scope :roots, -> { where(parent_id: nil) }

  after_commit :trigger_mention_wake, on: :create

  private

  def parent_belongs_to_same_task
    if parent.present? && parent.task_id != task_id
      errors.add(:parent, "must belong to the same task")
    end
  end

  def trigger_mention_wake
    company = task&.company
    return unless company

    mentioned_roles = detect_mentions(body, company)
    mentioned_roles.each do |role|
      trigger_role_wake(
        role: role,
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
end
