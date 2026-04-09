class RolesController < ApplicationController
  before_action :require_project!
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]

  def index
    @roles = Current.project.roles.includes(:parent, :children, :skills, :role_category, :goals).order(:title)
    @view = params[:view] || "chart"

    if @view == "chart"
      @roles_by_parent_id = @roles.group_by(&:parent_id)
      @root_roles = @roles_by_parent_id[nil] || []
    end
  end

  def show
    @detail = Role::Detail.new(@role, Current.project)
  end

  def new
    @role = Current.project.roles.new
    @role_categories = Current.project.role_categories.order(:name)
  end

  def create
    @role = Current.project.roles.new(role_params)

    if @role.save
      redirect_to @role, notice: "#{@role.title} has been created."
    else
      @role_categories = Current.project.role_categories.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @role_categories = Current.project.role_categories.order(:name)
  end

  def update
    if @role.update(role_params)
      sync_approval_gates
      redirect_to @role, notice: "#{@role.title} has been updated."
    else
      @role_categories = Current.project.role_categories.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role.destroy
    redirect_to roles_path, notice: "#{@role.title} has been deleted."
  end

  private

  def set_role
    @role = Current.project.roles.includes(:skills, :approval_gates, :role_skills, :role_category, children: [ :skills, :role_category ]).find(params[:id])
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
    permitted = params.require(:role).permit(:title, :role_category_id, :description, :job_spec, :parent_id, :working_directory, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars, :auto_hire_enabled)

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
