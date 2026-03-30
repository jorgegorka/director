class RoleHiringsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_role

  def create
    result = @role.hire!(
      template_role_title: hire_params[:template_role_title],
      budget_cents: hire_params[:budget_cents].to_i
    )

    if result.is_a?(Role)
      respond_to do |format|
        format.json { render json: { status: "ok", role_id: result.id, message: "Hired #{result.title}" }, status: :ok }
        format.html { redirect_to role_path(@role), notice: "#{result.title} has been hired." }
      end
    else
      respond_to do |format|
        format.json { render json: { status: "pending_approval", pending_hire_id: result.id, message: "Hire request for #{result.template_role_title} requires approval" }, status: :ok }
        format.html { redirect_to role_path(@role), notice: "Hire request for #{result.template_role_title} submitted for approval." }
      end
    end
  rescue Roles::Hiring::HiringError => e
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to role_path(@role), alert: e.message }
    end
  end

  private

  def set_role
    @role = Current.company.roles.find_by(id: params[:id])
    unless @role
      respond_to do |format|
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.html { raise ActiveRecord::RecordNotFound }
      end
    end
  end

  def hire_params
    params.permit(:template_role_title, :budget_cents)
  end
end
