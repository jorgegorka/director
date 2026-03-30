class RolesController < ApplicationController
  before_action :require_company!
  before_action :set_role, only: [ :show, :edit, :update, :destroy, :pause, :resume, :terminate, :approve, :reject ]

  def index
    @roles = Current.company.roles.includes(:parent, :children, :skills).order(:title)
  end

  def show
    @recent_heartbeats = @role.heartbeat_events.reverse_chronological.limit(5)
    @recent_runs = @role.role_runs.order(created_at: :desc).limit(5)
    @company_skills = Current.company.skills.order(:category, :name)
    @role_skills_by_skill_id = @role.role_skills.index_by(&:skill_id)
    @role_document_links = @role.role_documents.joins(:document).includes(:document).order("documents.title")
    @role_goals = @role.goals.ordered
    @eval_total = @role.goal_evaluations.count
    @eval_pass_count = @role.goal_evaluations.passed.count
    @recent_evaluations = @role.goal_evaluations.order(created_at: :desc).limit(5).includes(:task, :goal)
  end

  def new
    @role = Current.company.roles.new
  end

  def create
    @role = Current.company.roles.new(role_params)

    if @role.save
      redirect_to @role, notice: "#{@role.title} has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(role_params)
      sync_approval_gates
      redirect_to @role, notice: "#{@role.title} has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role.destroy
    redirect_to roles_path, notice: "#{@role.title} has been deleted."
  end

  def pause
    if @role.paused?
      redirect_to @role, alert: "#{@role.title} is already paused."
      return
    end

    if @role.terminated?
      redirect_to @role, alert: "Cannot pause a terminated role."
      return
    end

    @role.update!(
      status: :paused,
      pause_reason: params[:reason].presence || "Manually paused by #{Current.user.email_address}",
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "role_paused", metadata: { reason: @role.pause_reason })
    redirect_to @role, notice: "#{@role.title} has been paused."
  end

  def resume
    unless @role.paused? || @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not paused."
      return
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "role_resumed")
    redirect_to @role, notice: "#{@role.title} has been resumed."
  end

  def terminate
    if @role.terminated?
      redirect_to @role, alert: "#{@role.title} is already terminated."
      return
    end

    @role.update!(status: :terminated)
    @role.record_audit_event!(actor: Current.user, action: "role_terminated")
    redirect_to @role, notice: "#{@role.title} has been terminated."
  end

  def approve
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    if pending_hire
      @role.execute_hire!(pending_hire)
      pending_hire.approve!(Current.user)
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_approval")
    redirect_to @role, notice: "#{@role.title} has been approved and resumed."
  end

  def reject
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    pending_hire&.reject!(Current.user)

    @role.update!(
      status: :paused,
      pause_reason: "Approval rejected: #{params[:reason].presence || 'No reason given'}",
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_rejection", metadata: { reason: @role.pause_reason })
    redirect_to @role, notice: "#{@role.title} approval has been rejected."
  end

  private

  def set_role
    @role = Current.company.roles.includes(:skills, :approval_gates, :role_skills, children: :skills).find(params[:id])
  end

  def sync_approval_gates
    return unless params.dig(:role, :gates_submitted) == "1"

    raw_gates = params.dig(:role, :gates)
    gate_params = raw_gates ? raw_gates.permit(*ApprovalGate::GATABLE_ACTIONS) : ActionController::Parameters.new.permit!

    ApprovalGate::GATABLE_ACTIONS.each do |action_type|
      gate = @role.approval_gates.find_or_initialize_by(action_type: action_type)
      should_enable = gate_params[action_type] == "1"

      if should_enable
        gate.enabled = true
        gate.save!
      elsif gate.persisted?
        gate.update!(enabled: false)
      end
    end
  end

  def role_params
    permitted = params.require(:role).permit(:title, :description, :job_spec, :parent_id, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars, :auto_hire_enabled)

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

    adapter_type = permitted[:adapter_type] || @role&.adapter_type
    if adapter_type && params[:role][:adapter_config].is_a?(ActionController::Parameters)
      allowed_keys = AdapterRegistry.all_config_keys(adapter_type)
      permitted[:adapter_config] = params[:role][:adapter_config].permit(*allowed_keys).to_h
    end
    permitted
  end
end
