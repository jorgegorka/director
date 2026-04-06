class GoalsController < ApplicationController
  before_action :require_project!
  before_action :set_goal, only: [ :show, :edit, :update, :destroy ]

  def index
    @goals = Current.project.goals.ordered
  end

  def show
    @detail = Goal::Detail.new(@goal)
  end

  def new
    @goal = Current.project.goals.new
  end

  def create
    @goal = Current.project.goals.new(goal_params)

    if @goal.save
      respond_to do |format|
        format.turbo_stream if @goal.role_id
        format.html { redirect_to @goal, notice: "Goal '#{@goal.title}' has been created." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @goal.update(goal_params)
      redirect_to @goal, notice: "Goal '#{@goal.title}' has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @goal.title
    @goal.destroy
    redirect_to goals_path, notice: "Goal '#{title}' has been deleted."
  end

  private

  def set_goal
    @goal = Current.project.goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(:title, :description, :position, :role_id)
  end
end
