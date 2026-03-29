module Hookable
  extend ActiveSupport::Concern

  private

  # Map task status values to lifecycle event strings
  HOOKABLE_TRANSITIONS = {
    "in_progress" => RoleHook::AFTER_TASK_START,
    "completed" => RoleHook::AFTER_TASK_COMPLETE
  }.freeze

  def enqueue_hooks_for_transition
    return unless saved_change_to_status?
    return unless assignee_id.present?

    lifecycle_event = HOOKABLE_TRANSITIONS[status]
    return unless lifecycle_event

    hooks = assignee.role_hooks.enabled.for_event(lifecycle_event).ordered
    hooks.each do |hook|
      execution = HookExecution.create!(
        role_hook: hook,
        task: self,
        company_id: company_id,
        status: :queued,
        input_payload: build_hook_input_payload(hook)
      )
      ExecuteHookJob.perform_later(execution.id)
    end
  end

  def enqueue_validation_feedback
    return unless saved_change_to_status?
    return unless completed?
    return unless parent_task_id.present?

    ProcessValidationResultJob.perform_later(id)
  end

  def build_hook_input_payload(hook)
    {
      task_id: id,
      task_title: title,
      task_status: status,
      role_id: assignee_id,
      role_title: assignee.title,
      lifecycle_event: hook.lifecycle_event,
      hook_name: hook.name,
      action_type: hook.action_type,
      action_config: hook.action_config,
      triggered_at: Time.current.iso8601
    }
  end
end
