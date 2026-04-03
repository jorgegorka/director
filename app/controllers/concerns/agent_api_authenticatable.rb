module AgentApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    skip_before_action :require_authentication
    before_action :require_session_or_agent_token
  end

  private

  def current_actor
    @current_role || Current.user
  end

  def agent_api_request?
    @current_role.present?
  end

  def require_session_or_agent_token
    session_record = Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    if session_record
      Current.session = session_record
      set_current_company
      return
    end

    token = extract_bearer_token
    if token.present?
      @current_role = Role.find_by(api_token: token)
      if @current_role
        Current.company = @current_role.company
        return
      end
    end

    respond_to do |format|
      format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      format.html { request_authentication }
    end
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ", 2).last
  end

  def set_task
    @task = Current.company.tasks.find(params[:id])
  end

  def respond_success(task, message, **extra)
    respond_to do |format|
      format.json { render json: { status: "ok", task_id: task.id, assignee_id: task.assignee_id, message: message, **extra }, status: :ok }
      format.html { redirect_to task, notice: message }
    end
  end

  def respond_error(task, message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_to task, alert: message }
    end
  end
end
