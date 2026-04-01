class RecalculateGoalCompletionJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(goal_id)
    goal = Goal.find_by(id: goal_id)
    return unless goal

    goal.ancestry_chain.each(&:recalculate_completion!)
  end
end
