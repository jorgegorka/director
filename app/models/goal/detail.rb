class Goal::Detail
  attr_reader :goal

  def initialize(goal)
    @goal = goal
  end

  def tasks
    @tasks ||= goal.tasks.includes(:assignee, :creator).by_priority
  end

  def eval_total
    @eval_total ||= evaluations.count
  end

  def eval_pass_count
    @eval_pass_count ||= evaluations.passed.count
  end

  def eval_pass_rate
    return 0 if eval_total.zero?
    (eval_pass_count.to_f / eval_total * 100).round
  end

  def any_tasks?
    tasks.any?
  end

  def any_evaluations?
    eval_total > 0
  end

  private

    def evaluations
      @evaluations ||= goal.goal_evaluations
    end
end
