class GoalEvaluationService
  attr_reader :task

  def initialize(task)
    @task = task
  end

  def self.call(task)
    new(task).call
  end

  def call
    return unless task.completed?
    return unless task.goal.present?
    return if attempts_exhausted?

    result = evaluate
    evaluation = record_evaluation(result)

    if evaluation.fail?
      if evaluation.attempt_number >= GoalEvaluation::MAX_ATTEMPTS
        block_task(evaluation)
      else
        reopen_task(evaluation)
      end
    end

    evaluation
  end

  private

  def role
    @role ||= task.assignee
  end

  def goal
    @goal ||= task.goal
  end

  def eval_count
    @eval_count ||= task.goal_evaluations.count
  end

  def attempt_number
    eval_count + 1
  end

  def attempts_exhausted?
    eval_count >= GoalEvaluation::MAX_ATTEMPTS
  end

  def evaluate
    AiClient.chat(
      system: system_prompt,
      prompt: evaluation_prompt
    )
  end

  def system_prompt
    "You are evaluating whether a completed task advances a company goal. " \
    "Respond ONLY with valid JSON: {\"result\": \"pass\" or \"fail\", \"feedback\": \"2-3 sentence explanation\"}"
  end

  def evaluation_prompt
    parts = []
    parts << "## Goal Hierarchy"
    goal.ancestry_chain.each_with_index do |g, i|
      indent = "  " * i
      label = g.root? ? "Mission" : "Objective"
      parts << "#{indent}#{label}: #{g.title}"
      parts << "#{indent}  #{g.description}" if g.description.present?
    end

    parts << ""
    parts << "## Completed Task"
    parts << "Title: #{task.title}"
    parts << "Description: #{task.description}" if task.description.present?

    work_output = task.messages.order(:created_at).limit(50).pluck(:body)
    if work_output.any?
      parts << ""
      parts << "## Work Output"
      work_output.each { |body| parts << body }
    end

    parts << ""
    parts << "Evaluate whether this task's output meaningfully advances the stated goal."

    parts.join("\n")
  end

  def record_evaluation(result)
    cost_cents = AiClient.estimate_cost_cents(result[:usage])

    evaluation = GoalEvaluation.create!(
      company_id: task.company_id,
      task: task,
      goal: goal,
      role: role,
      result: result[:parsed]["result"],
      feedback: result[:parsed]["feedback"],
      attempt_number: attempt_number,
      cost_cents: cost_cents
    )

    charge_cost(cost_cents)
    evaluation
  end

  def charge_cost(cost_cents)
    return unless cost_cents&.positive?
    new_cost = (task.cost_cents || 0) + cost_cents
    task.update_column(:cost_cents, new_cost)
  end

  def reopen_task(evaluation)
    post_feedback_message(evaluation)
    task.update!(status: :in_progress)
    wake_role(evaluation)
  end

  def block_task(evaluation)
    post_feedback_message(evaluation)
    task.update!(status: :blocked)
    record_exhaustion_audit(evaluation)
  end

  def post_feedback_message(evaluation)
    Message.create!(
      task: task,
      author: role,
      body: build_feedback_body(evaluation)
    )
  end

  def build_feedback_body(evaluation)
    status = evaluation.pass? ? "PASS" : "FAIL"
    parts = []
    parts << "## Goal Evaluation — #{status} (Attempt #{evaluation.attempt_number}/#{GoalEvaluation::MAX_ATTEMPTS})"
    parts << ""
    parts << "**Goal:** #{goal.title}"
    parts << ""
    parts << evaluation.feedback

    if evaluation.fail? && evaluation.attempt_number >= GoalEvaluation::MAX_ATTEMPTS
      parts << ""
      parts << "_Evaluation attempts exhausted. Task has been blocked for review._"
    end

    parts.join("\n")
  end

  def wake_role(evaluation)
    return unless role
    return if role.terminated?

    Roles::Waking.call(
      role: role,
      trigger_type: :goal_evaluation_failed,
      trigger_source: "GoalEvaluation##{evaluation.id}",
      context: {
        task_id: task.id,
        task_title: task.title,
        goal_id: goal.id,
        goal_title: goal.title,
        attempt_number: evaluation.attempt_number,
        feedback: evaluation.feedback
      }
    )
  end

  def record_exhaustion_audit(evaluation)
    task.record_audit_event!(
      actor: role,
      action: "goal_evaluation_exhausted",
      company: task.company,
      metadata: {
        goal_id: goal.id,
        goal_title: goal.title,
        attempt_number: evaluation.attempt_number,
        feedback: evaluation.feedback
      }
    )
  end
end
