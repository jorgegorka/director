class Onboarding::CompletionsController < ApplicationController
  include Onboarding::Wizardable
  before_action :require_onboarding_project!

  def new
    @project = onboarding_project
    @roles = @project.roles.includes(:role_category).order(:id)
    @template = RoleTemplates::Registry.find(onboarding_state["template_key"]) if onboarding_state["template_key"]
  end

  def create
    session.delete(:onboarding)
    redirect_to roles_path, notice: "Your project is ready!"
  end
end
