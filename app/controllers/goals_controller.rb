class GoalsController < ApplicationController
  before_action :require_company!
  before_action :set_goal, only: [ :show, :edit, :update, :destroy ]

  def index
    @goals = Current.company.goals.roots.ordered
               .includes(children: { children: :children })  # 3 levels eager loaded
  end

  def show
    @children = @goal.children.ordered
    @tasks = @goal.tasks.includes(:assignee, :creator).by_priority
  end

  def new
    @goal = Current.company.goals.new(parent_id: params[:parent_id])
  end

  def create
    @goal = Current.company.goals.new(goal_params)

    if @goal.save
      redirect_to @goal, notice: "Goal '#{@goal.title}' has been created."
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
    @goal = Current.company.goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(:title, :description, :parent_id, :position)
  end
end
