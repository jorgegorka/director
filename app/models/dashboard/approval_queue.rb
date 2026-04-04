class Dashboard::ApprovalQueue
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def gate_blocked_roles
    @gate_blocked_roles ||= company.roles.where(status: :pending_approval).includes(:approval_gates).order(:paused_at)
  end

  def pending_hires
    @pending_hires ||= PendingHire.where(company: company, status: :pending).includes(:role).order(created_at: :desc)
  end

  def tasks_pending_review
    @tasks_pending_review ||= company.tasks.pending_human_review.includes(:assignee, :creator).order(updated_at: :desc)
  end

  def total_count
    gate_blocked_roles.size + pending_hires.size + tasks_pending_review.size
  end

  def any?
    total_count > 0
  end
end
