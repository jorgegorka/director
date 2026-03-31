class ExecuteRoleJob < ApplicationJob
  queue_as :execution

  # Do not retry execution jobs automatically -- failed runs should be
  # investigated or manually retried.
  discard_on ActiveJob::DeserializationError

  def perform(role_run_id)
    role_run = RoleRun.find_by(id: role_run_id)
    return unless role_run
    return if role_run.terminal?

    role = role_run.role
    role_run.mark_running!
    role.update!(status: :running)

    result = role.adapter_class.execute(role, build_context(role, role_run))

    role_run.mark_completed!(
      exit_code: result&.dig(:exit_code),
      cost_cents: result&.dig(:cost_cents),
      claude_session_id: result&.dig(:session_id)
    )
    role.update!(status: :idle)
  # NotImplementedError is a ScriptError (not StandardError) — catch it
  # explicitly so unimplemented adapters fail gracefully.
  rescue StandardError, NotImplementedError => e
    if role_run && !role_run.terminal?
      role_run.mark_failed!(error_message: e.message, exit_code: 1)
    end
    role&.update!(status: :idle) if role&.running?
  end

  private

  def build_context(role, role_run)
    ctx = {
      run_id: role_run.id,
      trigger_type: role_run.trigger_type
    }

    task = role_run.task
    if task
      ctx[:task_id] = task.id
      ctx[:task_title] = task.title
      ctx[:task_description] = task.description

      if task.goal
        ctx[:goal_id] = task.goal.id
        ctx[:goal_title] = task.goal.title
        ctx[:goal_description] = task.goal.description
      end
    end

    session_id = task ? role.latest_session_id_for(task) : role.latest_session_id
    ctx[:resume_session_id] = session_id if session_id.present?

    skills = role.skills.to_a
    ctx[:skills] = serialize_skills(skills)
    ctx[:documents] = build_document_context(skills, role, role_run)

    ctx
  end

  def build_document_context(skills, role, role_run)
    skill_doc_ids = SkillDocument.where(skill_id: skills.map(&:id)).pluck(:document_id)
    role_doc_ids = role.role_documents.pluck(:document_id)
    task_doc_ids = role_run.task_id.present? ? TaskDocument.where(task_id: role_run.task_id).pluck(:document_id) : []

    {
      skill_documents: serialize_documents(Document.where(id: skill_doc_ids)),
      role_documents: serialize_documents(Document.where(id: role_doc_ids)),
      task_documents: serialize_documents(Document.where(id: task_doc_ids))
    }
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

  def serialize_documents(documents)
    documents.includes(:tags).map do |doc|
      {
        id: doc.id,
        title: doc.title,
        body: doc.body,
        tags: doc.tags.map(&:name)
      }
    end
  end
end
