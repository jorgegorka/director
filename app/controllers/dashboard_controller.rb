class DashboardController < ApplicationController
  before_action :require_project!

  def show
    @current_tab = :overview
    load_common_data
  end

  private

  def load_common_data
    @overview = Dashboard::Overview.new(Current.project)
    @approvals_count = approval_pending_count
  end

  def approval_pending_count
    Current.project.approvals_pending_count
  end
end
