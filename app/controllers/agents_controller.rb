class AgentsController < ApplicationController
  before_action :require_company!
  before_action :set_agent, only: [ :show, :edit, :update, :destroy, :pause, :resume, :terminate, :approve, :reject ]

  def index
    @agents = Current.company.agents.includes(:agent_capabilities, :roles).order(:name)
  end

  def show
    @recent_heartbeats = @agent.heartbeat_events.reverse_chronological.limit(5)
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
    record_agent_audit("agent_paused", { reason: @agent.pause_reason })
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
    record_agent_audit("agent_resumed")
    redirect_to @agent, notice: "#{@agent.name} has been resumed."
  end

  def terminate
    if @agent.terminated?
      redirect_to @agent, alert: "#{@agent.name} is already terminated."
      return
    end

    @agent.update!(status: :terminated)
    record_agent_audit("agent_terminated")
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
    record_agent_audit("gate_approval", {
      action_type: @agent.pause_reason&.match(/: (.+) gate/)&.captures&.first
    })
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
    record_agent_audit("gate_rejection", {
      reason: @agent.pause_reason
    })
    redirect_to @agent, notice: "#{@agent.name} approval has been rejected."
  end

  private

  def set_agent
    @agent = Current.company.agents.includes(:agent_capabilities, :roles).find(params[:id])
  end

  def record_agent_audit(action, extra_metadata = {})
    AuditEvent.create!(
      auditable: @agent,
      actor: Current.user,
      action: action,
      company: Current.company,
      metadata: {
        agent_name: @agent.name,
        agent_id: @agent.id
      }.merge(extra_metadata)
    )
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
