class RolesController < ApplicationController
  before_action :require_company!
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]

  def index
    @roles = Current.company.roles.includes(:parent, :children, :agent).order(:title)
  end

  def show
  end

  def new
    @role = Current.company.roles.new
  end

  def create
    @role = Current.company.roles.new(role_params)

    if @role.save
      redirect_to @role, notice: "#{@role.title} role has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(role_params)
      redirect_to @role, notice: "#{@role.title} role has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role.destroy
    redirect_to roles_path, notice: "#{@role.title} role has been deleted."
  end

  private

  def set_role
    @role = Current.company.roles.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:title, :description, :job_spec, :parent_id, :agent_id)
  end
end
