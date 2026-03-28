module Runnable
  extend ActiveSupport::Concern

  # Shared state-machine transitions for models with status/started_at/completed_at/error_message.
  # Including models must define their own enum :status with at least :queued, :running, :completed, :failed.

  included do
    scope :recent, -> { where("created_at > ?", 24.hours.ago) }
  end

  def mark_running!
    raise "Cannot transition to running from #{status}" unless queued?
    update!(status: :running, started_at: Time.current)
  end

  def mark_failed!(error_message:)
    update!(status: :failed, error_message: error_message, completed_at: Time.current)
  end

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end
end
