class AgentCapabilitiesController < ApplicationController
  before_action :require_company!
  before_action :set_agent

  def create
    @capability = @agent.agent_capabilities.new(capability_params)
    if @capability.save
      redirect_to @agent, notice: "Capability '#{@capability.name}' added."
    else
      redirect_to @agent, alert: @capability.errors.full_messages.to_sentence
    end
  end

  def destroy
    @capability = @agent.agent_capabilities.find(params[:id])
    @capability.destroy
    redirect_to @agent, notice: "Capability '#{@capability.name}' removed."
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end

  def capability_params
    params.require(:agent_capability).permit(:name, :description)
  end
end
