class ProcessValidationResultService
  attr_reader :validation_task

  def initialize(validation_task)
    @validation_task = validation_task
  end

  def self.call(validation_task)
    new(validation_task).call
  end

  def call
    return unless parent_task
    return unless validation_task.completed?

    post_feedback_message
    wake_original_role
    record_audit_event
  end

  private

  def parent_task
    @parent_task ||= validation_task.parent_task
  end

  def parent_role
    @parent_role ||= parent_task.assignee
  end

  # --- Feedback message ---

  def post_feedback_message
    @feedback_message = Message.create!(
      task: parent_task,
      author: validation_author,
      body: build_feedback_body
    )
  end

  def validation_author
    validation_task.assignee || parent_role
  end

  def build_feedback_body
    parts = []
    parts << "## Validation Feedback"
    parts << ""
    parts << "**Validation task:** #{validation_task.title}"
    parts << "**Status:** #{validation_task.status}"
    parts << ""

    validation_messages = validation_task.messages.order(:created_at)
    if validation_messages.any?
      parts << "### Validation Results"
      parts << ""
      validation_messages.each do |msg|
        author_name = msg.author.respond_to?(:title) ? msg.author.title : msg.author.email_address
        parts << "> **#{author_name}:** #{msg.body}"
        parts << ""
      end
    else
      parts << "_No messages were posted during validation._"
    end

    parts.join("\n")
  end

  # --- Wake original role ---

  def wake_original_role
    return unless parent_role
    return if parent_role.terminated?

    WakeRoleService.call(
      role: parent_role,
      trigger_type: :review_validation,
      trigger_source: "Task##{validation_task.id}",
      context: {
        validation_task_id: validation_task.id,
        validation_task_title: validation_task.title,
        parent_task_id: parent_task.id,
        parent_task_title: parent_task.title,
        feedback_message_id: @feedback_message&.id
      }
    )
  end

  # --- Audit event ---

  def record_audit_event
    parent_task.record_audit_event!(
      actor: validation_author,
      action: "validation_feedback_received",
      company: parent_task.company,
      metadata: {
        validation_task_id: validation_task.id,
        validation_task_title: validation_task.title,
        parent_task_id: parent_task.id,
        parent_task_title: parent_task.title,
        feedback_message_id: @feedback_message&.id,
        message_count: validation_task.messages.count
      }
    )
  end
end
