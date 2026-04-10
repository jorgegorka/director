# Facade over root tasks (tasks with parent_task_id: nil). Kept as a
# separate controller + URL so the "Goals" nav label and /goals URL remain
# stable for users. Under the hood these are Task records.
class GoalsController < ApplicationController
  before_action :require_project!
  before_action :set_root_task, only: [ :show, :edit, :update, :destroy ]

  def index
    @root_tasks = Current.project.tasks.roots.by_priority
  end

  def show
    @detail = Task::Detail.new(@root_task)
  end

  def new
    @root_task = Current.project.tasks.new
  end

  def create
    @root_task = Current.project.tasks.new(root_task_params)
    @root_task.creator ||= default_creator

    if @root_task.creator.nil?
      @root_task.errors.add(:base, "Create a top-level role before creating a goal.")
      render :new, status: :unprocessable_entity
      return
    end

    if @root_task.save
      redirect_to goal_path(@root_task), notice: "Goal '#{@root_task.title}' has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @root_task.update(root_task_params)
      redirect_to goal_path(@root_task), notice: "Goal '#{@root_task.title}' has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @root_task.title
    @root_task.destroy
    redirect_to goals_path, notice: "Goal '#{title}' has been deleted."
  end

  private

  def set_root_task
    @root_task = Current.project.tasks.roots.find(params[:id])
  end

  def root_task_params
    params.require(:root_task).permit(:title, :description, :assignee_id, :priority)
  end

  def default_creator
    Current.project.roles.where(parent_id: nil).active.order(:created_at).first
  end
end
