class AuditEvent < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :actor, polymorphic: true

  validates :action, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :for_action, ->(action_name) { where(action: action_name) }

  # Immutability: prevent updates to persisted records
  def readonly?
    persisted?
  end
end
