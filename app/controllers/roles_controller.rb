class RolesController < ApplicationController
  before_action :require_project!
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]

  def index
    @roles = Current.project.roles.includes(:parent, :children, :skills, :role_category).order(:title)
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
    @role = Current.project.roles.new(new_role_defaults)
    @role_categories = Current.project.role_categories.order(:name)
    @reparent_child_id = reparent_child_id
  end

  def create
    @role = Current.project.roles.new(role_params)

    if reparent_child_id.present?
      child = Current.project.roles.find(reparent_child_id)
      @role.insert_above(child)
    else
      @role.save!
    end

    redirect_to @role, notice: "#{@role.title} has been created."
  rescue ActiveRecord::RecordInvalid
    @role_categories = Current.project.role_categories.order(:name)
    @reparent_child_id = reparent_child_id
    render :new, status: :unprocessable_entity
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

  def new_role_defaults
    return {} unless params[:role]

    params.require(:role).permit(:parent_id, :adapter_type, :working_directory, :role_category_id)
  end

  def reparent_child_id
    params[:reparent_child_id]
  end

  def role_params
    params.require(:role).permit(
      :title, :role_category_id, :description, :job_spec, :parent_id,
      :working_directory, :adapter_type, :heartbeat_enabled, :heartbeat_interval,
      :budget_dollars, :auto_hire_enabled,
      adapter_config: {}
    )
  end
end
