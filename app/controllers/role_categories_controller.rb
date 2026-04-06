class RoleCategoriesController < ApplicationController
  before_action :require_project!
  before_action :set_role_category, only: [ :show, :edit, :update, :destroy ]

  def index
    @role_categories = Current.project.role_categories.includes(:roles).order(:name)
  end

  def show
    @roles = @role_category.roles.order(:title)
  end

  def new
    @role_category = Current.project.role_categories.new
  end

  def create
    @role_category = Current.project.role_categories.new(role_category_params)

    if @role_category.save
      redirect_to @role_category, notice: "#{@role_category.name} category has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role_category.update(role_category_params)
      redirect_to @role_category, notice: "#{@role_category.name} category has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role_category.destroy
      redirect_to role_categories_path, notice: "#{@role_category.name} category has been deleted."
    else
      redirect_to @role_category, alert: @role_category.errors.full_messages.to_sentence
    end
  end

  private

  def set_role_category
    @role_category = Current.project.role_categories.find(params[:id])
  end

  def role_category_params
    params.require(:role_category).permit(:name, :description, :job_spec)
  end
end
