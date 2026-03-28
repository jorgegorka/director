class AgentSkillsController < ApplicationController
  before_action :require_company!
  before_action :set_agent

  def create
    skill = Current.company.skills.find(params[:skill_id])
    @agent.agent_skills.find_or_create_by!(skill: skill)
    redirect_to @agent, notice: "#{skill.name} assigned to #{@agent.name}."
  end

  def destroy
    agent_skill = @agent.agent_skills.find(params[:id])
    skill_name = agent_skill.skill.name
    agent_skill.destroy
    redirect_to @agent, notice: "#{skill_name} removed from #{@agent.name}."
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end
end
