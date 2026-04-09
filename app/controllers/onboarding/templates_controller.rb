class Onboarding::TemplatesController < ApplicationController
  include Onboarding::Wizardable
  before_action :require_onboarding_project!

  def new
    @templates = RoleTemplates::Registry.all
  end

  def create
    template_key = params[:template_key]

    if template_key.present? && template_key != "scratch"
      RoleTemplates::Applicator.call(project: onboarding_project, template_key: template_key)
      onboarding_state["template_key"] = template_key
    end

    if onboarding_state["template_key"].present?
      redirect_to new_onboarding_adapter_path
    else
      redirect_to new_onboarding_completion_path
    end
  end
end
