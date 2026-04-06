class SubAgentInvocation < ApplicationRecord
  include Tenantable

  belongs_to :role_run

  enum :status, { running: 0, completed: 1, failed: 2 }

  validates :sub_agent_name, presence: true
  validates :cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :iterations, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }

  # Starts a new invocation record tied to a role_run and returns it. The caller
  # drives the sub-agent loop, then calls #finish! or #fail! to close it out.
  def self.start!(role_run:, sub_agent_name:, input_summary: nil)
    create!(
      role_run: role_run,
      project: role_run.project,
      sub_agent_name: sub_agent_name,
      status: :running,
      input_summary: input_summary
    )
  end

  # Marks the invocation successful and atomically rolls its cost up into the
  # parent RoleRun so budget accounting stays accurate without waiting for the
  # outer adapter to finish.
  def finish!(result_summary:, cost_cents:, duration_ms:, iterations:)
    transaction do
      update!(
        status: :completed,
        result_summary: result_summary,
        cost_cents: cost_cents,
        duration_ms: duration_ms,
        iterations: iterations
      )
      roll_cost_into_parent_run!
    end
  end

  def fail!(error_message:, cost_cents: 0, duration_ms: nil, iterations: 0)
    transaction do
      update!(
        status: :failed,
        error_message: error_message,
        cost_cents: cost_cents,
        duration_ms: duration_ms,
        iterations: iterations
      )
      roll_cost_into_parent_run!
    end
  end

  private

  def roll_cost_into_parent_run!
    return unless cost_cents.to_i > 0
    RoleRun.update_counters(role_run_id, cost_cents: cost_cents)
  end
end
