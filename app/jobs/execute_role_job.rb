class ExecuteRoleJob < ApplicationJob
  include Triggerable

  queue_as :execution

  # Do not retry execution jobs automatically -- failed runs should be
  # investigated or manually retried.
  discard_on ActiveJob::DeserializationError

  def perform(role_run_id)
    role_run = RoleRun.find_by(id: role_run_id)
    return unless role_run
    return if role_run.terminal?

    role = role_run.role

    if role.adapter_type.blank?
      raise StandardError, "Role has no adapter configured — cannot execute. Configure an adapter type in role settings."
    end

    role_run.mark_running!
    role.update!(status: :running)

    result = role.adapter_class.execute(role, build_context(role, role_run))

    role_run.mark_completed!(
      exit_code: result&.dig(:exit_code),
      cost_cents: result&.dig(:cost_cents),
      claude_session_id: result&.dig(:session_id)
    )
    role.update!(status: :idle)
    role.company.dispatch_next_throttled_run!
  # NotImplementedError is a ScriptError (not StandardError) — catch it
  # explicitly so unimplemented adapters fail gracefully.
  rescue StandardError, NotImplementedError => e
    if role_run && !role_run.terminal?
      role_run.mark_failed!(error_message: e.message, exit_code: 1)
      notify_task_of_failure(role_run, e.message)
      escalate_to_manager(role_run, e.message)
    end
    role&.update!(status: :idle) if role&.running?
    role_run&.role&.company&.dispatch_next_throttled_run!
  end

  private

  def build_context(role, role_run)
    ctx = {
      run_id: role_run.id,
      trigger_type: role_run.trigger_type
    }

    task = role_run.task
    if task
      task.update!(status: :in_progress) if task.open?
      ctx[:task_id] = task.id
      ctx[:task_title] = task.title
      ctx[:task_description] = task.description
      ctx[:assignee_role_title] = task.assignee&.title
      goal = task.goal
    end

    goal ||= role_run.goal

    if goal
      ctx[:goal_id] = goal.id
      ctx[:goal_title] = goal.title
      ctx[:goal_description] = goal.description
    end

    session_id = task ? role.latest_session_id_for(task) : role.latest_session_id
    ctx[:resume_session_id] = session_id if session_id.present?

    skills = role.skills.to_a
    ctx[:skills] = serialize_skills(skills)
    ctx
  end

  def serialize_skills(skills)
    skills.map do |skill|
      {
        key: skill.key,
        name: skill.name,
        description: skill.description,
        category: skill.category,
        markdown: skill.markdown
      }
    end
  end

  def notify_task_of_failure(role_run, reason)
    task = role_run.task
    return unless task

    Message.create!(
      task: task,
      author: role_run.role,
      message_type: :comment,
      body: "My session ended without completing work. Reason: #{reason}"
    )
  end

  def escalate_to_manager(role_run, reason)
    task = role_run.task
    return unless task&.creator
    return if task.creator.terminated?

    trigger_role_wake(
      role: task.creator,
      trigger_type: :task_assigned,
      trigger_source: "ExecuteRoleJob##{role_run.id}",
      context: { task_id: task.id, task_title: task.title }
    )
  end
end
