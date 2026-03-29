class WakeRoleService
  attr_reader :role, :trigger_type, :trigger_source, :context

  def initialize(role:, trigger_type:, trigger_source: nil, context: {})
    @role = role
    @trigger_type = trigger_type.to_s
    @trigger_source = trigger_source
    @context = context.with_indifferent_access
  end

  def call
    return nil if role.terminated?

    event = create_event
    deliver(event)
    update_role_heartbeat_timestamp
    event
  end

  def self.call(**args)
    new(**args).call
  end

  private

  def create_event
    role.heartbeat_events.create!(
      trigger_type: trigger_type,
      trigger_source: trigger_source,
      status: initial_status,
      request_payload: build_request_payload
    )
  end

  def initial_status
    role.http? ? :delivered : :queued
  end

  def deliver(event)
    if role.http?
      deliver_http(event)
    else
      event
    end

    dispatch_execution(event)
  rescue StandardError => e
    event.mark_failed!(error_message: e.message)
    event
  end

  def deliver_http(event)
    event.mark_delivered!(response: { status: "acknowledged" })
    event
  end

  def dispatch_execution(event)
    return if role.role_runs.active.exists?

    role_run = role.role_runs.create!(
      task_id: context[:task_id],
      company_id: role.company_id,
      status: :queued,
      trigger_type: trigger_type
    )

    ExecuteRoleJob.perform_later(role_run.id)
    role_run
  end

  def build_request_payload
    {
      trigger: trigger_type,
      role_id: role.id,
      role_title: role.title,
      company_id: role.company_id,
      triggered_at: Time.current.iso8601
    }.merge(context)
  end

  def update_role_heartbeat_timestamp
    role.update_column(:last_heartbeat_at, Time.current)
  end
end
