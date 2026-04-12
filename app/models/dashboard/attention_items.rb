class Dashboard::AttentionItems
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def tasks_pending_review
    @tasks_pending_review ||= project.tasks.pending_human_review
      .includes(:assignee, :creator, :parent_task)
      .order(updated_at: :desc)
  end

  def gate_blocked_roles
    @gate_blocked_roles ||= project.roles
      .where(status: :pending_approval)
      .includes(:approval_gates)
      .order(:paused_at)
  end

  def pending_hires
    @pending_hires ||= PendingHire
      .where(project: project, status: :pending)
      .includes(:role)
      .order(created_at: :desc)
  end

  def blocked_tasks
    @blocked_tasks ||= project.tasks.blocked
      .includes(:assignee, :parent_task)
      .order(updated_at: :desc)
  end

  def total_count
    tasks_pending_review.size + gate_blocked_roles.size +
      pending_hires.size + blocked_tasks.size
  end

  def any?
    tasks_pending_review.any? || gate_blocked_roles.any? ||
      pending_hires.any? || blocked_tasks.any?
  end

  def broadcast_to(project_id)
    content = if any?
      ApplicationController.render(
        partial: "dashboard/attention_section",
        formats: [ :html ],
        locals: { attention: self }
      )
    else
      ""
    end

    Turbo::StreamsChannel.broadcast_update_to(
      "dashboard_project_#{project_id}",
      target: "dashboard-attention",
      html: content
    )
  end
end
