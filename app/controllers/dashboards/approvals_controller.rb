class Dashboards::ApprovalsController < ApplicationController
  before_action :require_company!
  layout false

  def index
    @approval_queue = Dashboard::ApprovalQueue.new(Current.company)
  end
end
