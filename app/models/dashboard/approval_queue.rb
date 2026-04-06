class Dashboard::ApprovalQueue
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def gate_blocked_roles
    @gate_blocked_roles ||= project.roles.where(status: :pending_approval).includes(:approval_gates).order(:paused_at)
  end

  def pending_hires
    @pending_hires ||= PendingHire.where(project: project, status: :pending).includes(:role).order(created_at: :desc)
  end

  def tasks_pending_review
    @tasks_pending_review ||= project.tasks.pending_human_review.includes(:assignee, :creator).order(updated_at: :desc)
  end

  def total_count
    gate_blocked_roles.size + pending_hires.size + tasks_pending_review.size
  end

  def any?
    total_count > 0
  end
end
