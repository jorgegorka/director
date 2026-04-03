class Dashboards::ApprovalsController < DashboardController
  def index
    @current_tab = :approvals
    load_common_data
    @approval_queue = Dashboard::ApprovalQueue.new(Current.company)
    render "dashboard/show"
  end
end
