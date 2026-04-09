class Onboarding::ProjectsController < ApplicationController
  include Onboarding::Wizardable

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    Project.transaction do
      @project.save!
      @project.memberships.create!(user: Current.user, role: :owner)
    end

    session[:project_id] = @project.id
    onboarding_state["project_id"] = @project.id
    redirect_to new_onboarding_template_path
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
