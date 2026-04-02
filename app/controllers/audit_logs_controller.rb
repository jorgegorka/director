class AuditLogsController < ApplicationController
  before_action :require_company!

  def index
    @index = AuditEvent::Index.new(Current.company, filter_params)
  end

  private

    def filter_params
      params.permit(:actor_type, :action_filter, :start_date, :end_date).to_h.symbolize_keys
    end
end
