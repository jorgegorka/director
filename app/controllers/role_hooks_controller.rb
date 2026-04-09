class RoleHooksController < ApplicationController
  before_action :require_project!
  before_action :set_role
  before_action :set_role_hook, only: [ :show, :edit, :update, :destroy ]

  def index
    @role_hooks = @role.role_hooks.ordered
  end

  def show
    @executions_count = @role_hook.hook_executions.count
    @recent_executions = @role_hook.hook_executions.order(created_at: :desc).limit(5)
  end

  def new
    @role_hook = @role.role_hooks.new(enabled: true, position: next_position)
  end

  def create
    @role_hook = @role.role_hooks.new(role_hook_params)
    @role_hook.project = Current.project

    if @role_hook.save
      redirect_to role_role_hook_url(@role, @role_hook), notice: "Hook \"#{@role_hook.name}\" has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role_hook.update(role_hook_params)
      redirect_to role_role_hook_url(@role, @role_hook), notice: "Hook \"#{@role_hook.name}\" has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @role_hook.name
    @role_hook.destroy
    redirect_to role_role_hooks_url(@role), notice: "Hook \"#{name}\" has been deleted."
  end

  private

  def set_role
    @role = Current.project.roles.find(params[:role_id])
  end

  def set_role_hook
    @role_hook = @role.role_hooks.find(params[:id])
  end

  def next_position
    (@role.role_hooks.maximum(:position) || -1) + 1
  end

  ACTION_CONFIG_KEYS = {
    "trigger_agent" => %i[target_role_id target_agent_id prompt],
    "webhook" => %i[url headers timeout]
  }.freeze

  def role_hook_params
    permitted = params.require(:role_hook).permit(:name, :lifecycle_event, :action_type, :enabled, :position)

    if params[:role_hook][:action_config].is_a?(ActionController::Parameters)
      allowed = ACTION_CONFIG_KEYS.fetch(permitted[:action_type], [])
      permitted[:action_config] = params[:role_hook][:action_config].permit(*allowed).to_h
    end

    permitted
  end
end
