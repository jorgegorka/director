class AgentHooksController < ApplicationController
  before_action :require_company!
  before_action :set_agent
  before_action :set_agent_hook, only: [ :show, :edit, :update, :destroy ]

  def index
    @agent_hooks = @agent.agent_hooks.ordered
  end

  def show
    @executions_count = @agent_hook.hook_executions.count
    @recent_executions = @agent_hook.hook_executions.order(created_at: :desc).limit(5)
  end

  def new
    @agent_hook = @agent.agent_hooks.new(enabled: true, position: next_position)
  end

  def create
    @agent_hook = @agent.agent_hooks.new(agent_hook_params)
    @agent_hook.company = Current.company

    if @agent_hook.save
      redirect_to agent_agent_hook_url(@agent, @agent_hook), notice: "Hook \"#{@agent_hook.name}\" has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent_hook.update(agent_hook_params)
      redirect_to agent_agent_hook_url(@agent, @agent_hook), notice: "Hook \"#{@agent_hook.name}\" has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @agent_hook.name
    @agent_hook.destroy
    redirect_to agent_agent_hooks_url(@agent), notice: "Hook \"#{name}\" has been deleted."
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end

  def set_agent_hook
    @agent_hook = @agent.agent_hooks.find(params[:id])
  end

  def next_position
    (@agent.agent_hooks.maximum(:position) || -1) + 1
  end

  def agent_hook_params
    permitted = params.require(:agent_hook).permit(:name, :lifecycle_event, :action_type, :enabled, :position)

    # Handle action_config as nested hash -- keys vary by action_type
    if params[:agent_hook][:action_config].is_a?(ActionController::Parameters)
      permitted[:action_config] = params[:agent_hook][:action_config].permit!.to_h
    end

    permitted
  end
end
