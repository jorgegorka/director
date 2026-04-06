class Role::Detail
  attr_reader :role, :project

  def initialize(role, project)
    @role = role
    @project = project
  end

  def recent_heartbeats
    @recent_heartbeats ||= role.heartbeat_events.reverse_chronological.limit(5)
  end

  def recent_runs
    @recent_runs ||= role.role_runs.order(created_at: :desc).limit(5)
  end

  def project_skills
    @project_skills ||= project.skills.order(:category, :name)
  end

  def role_skills_by_skill_id
    @role_skills_by_skill_id ||= role.role_skills.index_by(&:skill_id)
  end

  def role_goals
    @role_goals ||= role.goals.ordered
  end

  def eval_total
    @eval_total ||= role.goal_evaluations.count
  end

  def eval_pass_count
    @eval_pass_count ||= role.goal_evaluations.passed.count
  end

  def recent_evaluations
    @recent_evaluations ||= role.goal_evaluations.order(created_at: :desc).limit(5).includes(:task, :goal)
  end

  def any_evaluations?
    eval_total > 0
  end

  def eval_pass_rate
    return 0 if eval_total.zero?
    (eval_pass_count.to_f / eval_total * 100).round
  end
end
