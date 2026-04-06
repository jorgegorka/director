module Tools
  # Orchestrator-facing `review_task` tool. Delegates to the ReviewTask
  # sub-agent, which reads the submission and decides approve/reject.
  #
  # When approval causes a goal to reach 100% completion, automatically
  # chains the SummarizeGoal sub-agent so the user gets an outcome summary
  # without the orchestrator needing to remember to call summarize_goal.
  class ReviewTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::ReviewTask

    def call(arguments)
      result = super
      if result.is_a?(Hash) && result[:status] == "ok"
        if (summarized_goal_id = auto_summarize_completed_goal(arguments["task_id"]))
          result[:goal_summarized] = summarized_goal_id
        end
      end
      result
    end

    private

    def auto_summarize_completed_goal(task_id)
      task = project.tasks.find_by(id: task_id)
      return unless task&.goal

      goal = task.goal
      total = goal.tasks.count
      return if total.zero?
      return unless total == goal.tasks.completed.count
      return if goal.summary.present?

      SubAgents::SummarizeGoal.new(
        role: role,
        arguments: { "goal_id" => goal.id },
        parent_role_run: resolve_parent_role_run
      ).call

      goal.id
    end
  end
end
