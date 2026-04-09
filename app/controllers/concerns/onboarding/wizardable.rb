module Onboarding::Wizardable
  extend ActiveSupport::Concern

  included do
    before_action :redirect_if_onboarded
    helper_method :wizard_steps, :current_step_number, :onboarding_project
  end

  private

  def onboarding_state
    session[:onboarding] ||= {}
  end

  def onboarding_project
    @onboarding_project ||= Current.user.projects.find_by(id: onboarding_state["project_id"])
  end

  def redirect_if_onboarded
    redirect_to root_path if Current.user.projects.any? && onboarding_state.blank?
  end

  def require_onboarding_project!
    redirect_to new_onboarding_project_path unless onboarding_project
  end

  def wizard_steps
    steps = %w[project template]
    steps << "adapter" if onboarding_state["template_key"].present?
    steps << "completion"
    steps
  end

  def current_step_number
    step_name = controller_name.singularize
    wizard_steps.index(step_name)&.+(1) || 1
  end
end
