module Roles
  class Waking
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
      if role.adapter_type.blank?
        event.mark_failed!(error_message: "Role has no adapter configured")
        return
      end

      # Defense in depth: short-circuit any trigger targeting a done task.
      if context[:task_id].present?
        task = Task.find_by(id: context[:task_id])
        if task&.terminal?
          event.mark_delivered!(response: { status: "skipped_terminal_task", task_status: task.status })
          return
        end
      end

      run_attrs = {
        task_id: context[:task_id],
        goal_id: context[:goal_id],
        company_id: role.company_id,
        trigger_type: trigger_type
      }

      active_run = role.role_runs.active.first
      if active_run
        attach_goal_to_active_run(active_run) if context[:goal_id].present?
        role.role_runs.create!(**run_attrs, status: :throttled) if context[:task_id].present?
        return
      end

      if role.company.concurrent_agent_limit_reached?
        role.role_runs.create!(**run_attrs, status: :throttled)
        return
      end

      role_run = role.role_runs.create!(**run_attrs, status: :queued)
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

    def attach_goal_to_active_run(active_run)
      return if active_run.goal_id.present?
      active_run.update_column(:goal_id, context[:goal_id])
    end

    def update_role_heartbeat_timestamp
      role.update_column(:last_heartbeat_at, Time.current)
    end
  end
end
