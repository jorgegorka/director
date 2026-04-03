class DashboardController < ApplicationController
  before_action :require_company!

  def show
    @current_tab = :overview
    load_common_data
  end

  private

  def load_common_data
    @overview = Dashboard::Overview.new(Current.company)
    @approvals_count = approval_pending_count
  end

  def approval_pending_count
    Current.company.roles.where(status: :pending_approval).count +
      PendingHire.where(company: Current.company, status: :pending).count +
      Current.company.tasks.where(status: :pending_review).count
  end
end
