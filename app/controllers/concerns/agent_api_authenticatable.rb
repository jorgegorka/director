module AgentApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    # Skip the standard session-based require_authentication for these controllers.
    # We handle auth ourselves: accept session OR Bearer token.
    skip_before_action :require_authentication
    before_action :require_session_or_agent_token
  end

  private

  # The actor for audit events: either the authenticated agent or the session user.
  def current_actor
    @current_agent || Current.user
  end

  # True if the request came from an agent via Bearer token.
  def agent_api_request?
    @current_agent.present?
  end

  # Authenticate via session cookie (human) OR Authorization Bearer token (agent).
  # At least one must succeed. If neither, return 401.
  def require_session_or_agent_token
    # Try session auth first (sets Current.session and Current.user)
    if find_session_by_cookie
      Current.session = find_session_by_cookie
      set_current_company_from_session
      return
    end

    # Try Bearer token auth
    token = extract_bearer_token
    if token.present?
      @current_agent = Agent.find_by(api_token: token)
      if @current_agent
        # Set Current.company from the agent's company for Tenantable scoping
        Current.company = @current_agent.company
        return
      end
    end

    # Neither auth method succeeded
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

  def find_session_by_cookie
    @_cached_session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def set_current_company_from_session
    return unless Current.user

    if session[:company_id]
      Current.company = Current.user.companies.find_by(id: session[:company_id])
    end
    if Current.company.nil? && Current.user.companies.any?
      Current.company = Current.user.companies.first
    end
  end

  # Respond appropriately based on caller type.
  # Agent API callers get JSON; human UI callers get redirects.
  def respond_success(task, message)
    respond_to do |format|
      format.json { render json: { status: "ok", task_id: task.id, assignee_id: task.assignee_id, message: message }, status: :ok }
      format.html { redirect_to task, notice: message }
    end
  end

  def respond_error(task, message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_to task, alert: message }
    end
  end

  def respond_not_found
    respond_to do |format|
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.html { raise ActiveRecord::RecordNotFound }
    end
  end
end
