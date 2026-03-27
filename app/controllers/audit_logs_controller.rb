class AuditLogsController < ApplicationController
  before_action :require_company!

  def index
    @audit_events = base_scope

    if params[:actor_type].present?
      @audit_events = @audit_events.for_actor_type(params[:actor_type])
    end

    if params[:action_filter].present?
      @audit_events = @audit_events.for_action(params[:action_filter])
    end

    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      end_date = Date.parse(params[:end_date]) rescue nil
      if start_date && end_date
        @audit_events = @audit_events.for_date_range(start_date, end_date)
      end
    end

    @audit_events = @audit_events
                      .reverse_chronological
                      .includes(:actor, :auditable)
                      .limit(100)

    @available_actions = base_scope.distinct.pluck(:action).sort
    @available_actor_types = base_scope.distinct.pluck(:actor_type).compact.sort
  end

  private

  def base_scope
    AuditEvent.for_company(Current.company)
  end
end
