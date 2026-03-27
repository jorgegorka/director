class Message < ApplicationRecord
  include Triggerable

  belongs_to :task
  belongs_to :author, polymorphic: true
  belongs_to :parent, class_name: "Message", optional: true

  has_many :replies, class_name: "Message", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  validates :body, presence: true
  validate :parent_belongs_to_same_task

  scope :roots, -> { where(parent_id: nil) }
  scope :chronological, -> { order(:created_at) }

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

    mentioned_agents = detect_mentions(body, company)
    mentioned_agents.each do |agent|
      trigger_agent_wake(
        agent: agent,
        trigger_type: :mention,
        trigger_source: "Message##{id}",
        context: {
          message_id: id,
          task_id: task_id,
          mentioned_by: author_type == "User" ? "user" : "agent"
        }
      )
    end
  end
end
