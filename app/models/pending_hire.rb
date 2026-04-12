class PendingHire < ApplicationRecord
  include Tenantable

  belongs_to :role
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :template_role_title, presence: true
  validates :budget_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :must_be_pending_to_resolve, on: :update

  scope :actionable, -> { where(status: :pending) }

  def approve!(user, feedback: nil)
    assert_pending!
    update!(status: :approved, resolved_by: user, resolved_at: Time.current, feedback: feedback.presence)
  end

  def reject!(user, feedback: nil)
    assert_pending!
    update!(status: :rejected, resolved_by: user, resolved_at: Time.current, feedback: feedback.presence)
  end

  private

  def assert_pending!
    return if pending?

    errors.add(:status, "can only be changed from pending")
    raise ActiveRecord::RecordInvalid, self
  end

  def must_be_pending_to_resolve
    if status_changed? && status_was != "pending"
      errors.add(:status, "can only be changed from pending")
    end
  end
end
