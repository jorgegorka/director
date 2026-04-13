class Goals::RecurrencesController < ApplicationController
  before_action :require_project!
  before_action :set_goal

  def destroy
    @goal.stop_recurring
    redirect_to goal_path(@goal), notice: "Recurrence stopped for '#{@goal.title}'."
  end

  private

  def set_goal
    @goal = Current.project.tasks.roots.find(params[:goal_id])
  end
end
