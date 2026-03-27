class Message < ApplicationRecord
  belongs_to :task
  belongs_to :author, polymorphic: true
  belongs_to :parent, class_name: "Message", optional: true

  has_many :replies, class_name: "Message", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  validates :body, presence: true
  validate :parent_belongs_to_same_task

  scope :roots, -> { where(parent_id: nil) }
  scope :chronological, -> { order(:created_at) }

  private

  def parent_belongs_to_same_task
    if parent.present? && parent.task_id != task_id
      errors.add(:parent, "must belong to the same task")
    end
  end
end
