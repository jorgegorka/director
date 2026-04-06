class Dashboards::ActivitiesController < DashboardController
  def index
    @current_tab = :activities
    load_common_data
    @activity_events = AuditEvent.for_project(Current.project)
    @activity_events = @activity_events.filter_by_role(params[:role_filter]) if params[:role_filter].present?
    @activity_events = @activity_events.reverse_chronological.includes(:actor, :auditable).limit(50)
    @filter_roles = Current.project.roles.active.order(:title)
    render "dashboard/show"
  end
end
