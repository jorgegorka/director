class ExecuteAgentJob < ApplicationJob
  queue_as :execution

  # Do not retry execution jobs automatically -- failed runs should be
  # investigated or manually retried.
  discard_on ActiveJob::DeserializationError

  def perform(agent_run_id)
    agent_run = AgentRun.find_by(id: agent_run_id)
    return unless agent_run
    return if agent_run.terminal?

    agent = agent_run.agent
    agent_run.mark_running!
    agent.update!(status: :running)

    result = agent.adapter_class.execute(agent, build_context(agent, agent_run))

    agent_run.mark_completed!(
      exit_code: result&.dig(:exit_code),
      cost_cents: result&.dig(:cost_cents),
      claude_session_id: result&.dig(:session_id)
    )
    agent.update!(status: :idle)
  # NotImplementedError is a ScriptError (not StandardError) — catch it
  # explicitly so unimplemented adapters fail gracefully.
  rescue StandardError, NotImplementedError => e
    if agent_run && !agent_run.terminal?
      agent_run.mark_failed!(error_message: e.message, exit_code: 1)
    end
    agent&.update!(status: :idle) if agent&.running?
  end

  private

  def build_context(agent, agent_run)
    ctx = {
      run_id: agent_run.id,
      trigger_type: agent_run.trigger_type
    }

    if agent_run.task_id.present?
      task = agent_run.task
      ctx[:task_id] = agent_run.task_id
      ctx[:task_title] = task.title
      ctx[:task_description] = task.description
    end

    session_id = agent.latest_session_id
    ctx[:resume_session_id] = session_id if session_id.present?

    skills = agent.skills.to_a
    ctx[:skills] = serialize_skills(skills)
    ctx[:documents] = build_document_context(skills, agent, agent_run)

    ctx
  end

  def build_document_context(skills, agent, agent_run)
    skill_doc_ids = SkillDocument.where(skill_id: skills.map(&:id)).pluck(:document_id)
    agent_doc_ids = agent.agent_documents.pluck(:document_id)
    task_doc_ids = agent_run.task_id.present? ? TaskDocument.where(task_id: agent_run.task_id).pluck(:document_id) : []

    {
      skill_documents: serialize_documents(Document.where(id: skill_doc_ids)),
      agent_documents: serialize_documents(Document.where(id: agent_doc_ids)),
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
