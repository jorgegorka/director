class Projects::SwitchesController < ApplicationController
  def create
    project = Current.user.projects.find(params[:project_id])
    session[:project_id] = project.id
    redirect_to root_path, notice: "Switched to #{project.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "Project not found."
  end
end
