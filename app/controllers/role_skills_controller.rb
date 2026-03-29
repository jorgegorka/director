class RoleSkillsController < ApplicationController
  before_action :require_company!
  before_action :set_role

  def create
    skill = Current.company.skills.find(params[:skill_id])
    @role.role_skills.find_or_create_by!(skill: skill)
    redirect_to @role, notice: "#{skill.name} assigned to #{@role.title}."
  end

  def destroy
    role_skill = @role.role_skills.find(params[:id])
    skill_name = role_skill.skill.name
    role_skill.destroy
    redirect_to @role, notice: "#{skill_name} removed from #{@role.title}."
  end

  private

  def set_role
    @role = Current.company.roles.find(params[:role_id])
  end
end
