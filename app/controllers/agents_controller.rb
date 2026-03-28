class AgentsController < ApplicationController
  before_action :require_company!
  before_action :set_agent, only: [ :show, :edit, :update, :destroy, :pause, :resume, :terminate, :approve, :reject ]

  def index
    @agents = Current.company.agents.includes(:skills, :roles).order(:name)
  end

  def show
    @recent_heartbeats = @agent.heartbeat_events.reverse_chronological.limit(5)
    @recent_runs = @agent.agent_runs.order(created_at: :desc).limit(5)
    @company_skills = Current.company.skills.order(:category, :name)
    @agent_skills_by_skill_id = @agent.agent_skills.index_by(&:skill_id)
    @agent_document_links = @agent.agent_documents.joins(:document).includes(:document).order("documents.title")
  end

  def new
    @agent = Current.company.agents.new(adapter_type: :http)
  end

  def create
    @agent = Current.company.agents.new(agent_params)

    if @agent.save
      redirect_to @agent, notice: "#{@agent.name} has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent.update(agent_params)
      sync_approval_gates
      redirect_to @agent, notice: "#{@agent.name} has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agent.destroy
    redirect_to agents_path, notice: "#{@agent.name} has been deleted."
  end

  def pause
    if @agent.paused?
      redirect_to @agent, alert: "#{@agent.name} is already paused."
      return
    end

    if @agent.terminated?
      redirect_to @agent, alert: "Cannot pause a terminated agent."
      return
    end

    @agent.update!(
      status: :paused,
      pause_reason: params[:reason].presence || "Manually paused by #{Current.user.email_address}",
      paused_at: Time.current
    )
    @agent.record_audit_event!(actor: Current.user, action: "agent_paused", metadata: { reason: @agent.pause_reason })
    redirect_to @agent, notice: "#{@agent.name} has been paused."
  end

  def resume
    unless @agent.paused? || @agent.pending_approval?
      redirect_to @agent, alert: "#{@agent.name} is not paused."
      return
    end

    @agent.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @agent.record_audit_event!(actor: Current.user, action: "agent_resumed")
    redirect_to @agent, notice: "#{@agent.name} has been resumed."
  end

  def terminate
    if @agent.terminated?
      redirect_to @agent, alert: "#{@agent.name} is already terminated."
      return
    end

    @agent.update!(status: :terminated)
    @agent.record_audit_event!(actor: Current.user, action: "agent_terminated")
    redirect_to @agent, notice: "#{@agent.name} has been terminated."
  end

  def approve
    unless @agent.pending_approval?
      redirect_to @agent, alert: "#{@agent.name} is not pending approval."
      return
    end

    @agent.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @agent.record_audit_event!(actor: Current.user, action: "gate_approval")
    redirect_to @agent, notice: "#{@agent.name} has been approved and resumed."
  end

  def reject
    unless @agent.pending_approval?
      redirect_to @agent, alert: "#{@agent.name} is not pending approval."
      return
    end

    @agent.update!(
      status: :paused,
      pause_reason: "Approval rejected: #{params[:reason].presence || 'No reason given'}",
      paused_at: Time.current
    )
    @agent.record_audit_event!(actor: Current.user, action: "gate_rejection", metadata: { reason: @agent.pause_reason })
    redirect_to @agent, notice: "#{@agent.name} approval has been rejected."
  end

  private

  def set_agent
    @agent = Current.company.agents.includes(:skills, :roles, :approval_gates, :agent_skills).find(params[:id])
  end

  def sync_approval_gates
    # gates_submitted signals the gate fieldset was present in the form.
    # Without it, we skip syncing (e.g., API calls or programmatic updates).
    return unless params.dig(:agent, :gates_submitted) == "1"

    # gates key may be absent when all checkboxes are unchecked
    raw_gates = params.dig(:agent, :gates)
    gate_params = raw_gates ? raw_gates.permit(*ApprovalGate::GATABLE_ACTIONS) : ActionController::Parameters.new.permit!

    ApprovalGate::GATABLE_ACTIONS.each do |action_type|
      gate = @agent.approval_gates.find_or_initialize_by(action_type: action_type)
      should_enable = gate_params[action_type] == "1"

      if should_enable
        gate.enabled = true
        gate.save!
      elsif gate.persisted?
        gate.update!(enabled: false)
      end
    end
  end

  def agent_params
    permitted = params.require(:agent).permit(:name, :description, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars)

    # Convert budget_dollars to budget_cents
    if permitted.key?(:budget_dollars)
      dollars = permitted.delete(:budget_dollars)
      if dollars.present?
        permitted[:budget_cents] = (dollars.to_f * 100).round
        permitted[:budget_period_start] = Date.current.beginning_of_month
      else
        permitted[:budget_cents] = nil
        permitted[:budget_period_start] = nil
      end
    end

    adapter_type = permitted[:adapter_type] || @agent&.adapter_type
    if adapter_type && params[:agent][:adapter_config].is_a?(ActionController::Parameters)
      allowed_keys = AdapterRegistry.all_config_keys(adapter_type)
      permitted[:adapter_config] = params[:agent][:adapter_config].permit(*allowed_keys).to_h
    end
    permitted
  end
end
