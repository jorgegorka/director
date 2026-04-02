class Task::Detail
  attr_reader :task

  def initialize(task)
    @task = task
  end

  def messages
    @messages ||= task.messages.includes(:author, replies: :author).roots.chronological
  end

  def audit_events
    @audit_events ||= task.audit_events.includes(:actor).reverse_chronological
  end

  def new_message
    @new_message ||= Message.new
  end

  def document_links
    @document_links ||= task.task_documents.joins(:document).includes(:document).order("documents.title")
  end

  def goal_evaluations
    @goal_evaluations ||= task.goal_evaluations.order(:attempt_number).includes(:goal)
  end

  def any_messages?
    messages.any?
  end

  def any_documents?
    document_links.any?
  end

  def any_evaluations?
    goal_evaluations.any?
  end
end
