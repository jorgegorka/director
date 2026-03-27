class AgentsController < ApplicationController
  before_action :require_company!
  before_action :set_agent, only: [ :show, :edit, :update, :destroy ]

  def index
    @agents = Current.company.agents.includes(:agent_capabilities, :roles).order(:name)
  end

  def show
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

  private

  def set_agent
    @agent = Current.company.agents.includes(:agent_capabilities, :roles).find(params[:id])
  end

  def agent_params
    permitted = params.require(:agent).permit(:name, :description, :adapter_type)
    adapter_type = permitted[:adapter_type] || @agent&.adapter_type
    if adapter_type && params[:agent][:adapter_config].is_a?(ActionController::Parameters)
      allowed_keys = AdapterRegistry.all_config_keys(adapter_type)
      permitted[:adapter_config] = params[:agent][:adapter_config].permit(*allowed_keys).to_h
    end
    permitted
  end
end
