module Tools
  # Orchestrator-facing `review_task` tool. Delegates to the ReviewTask
  # sub-agent, which reads the submission and decides approve/reject.
  #
  # When approval causes a root task to reach 100% completion, automatically
  # chains the SummarizeTask sub-agent so the user gets an outcome summary
  # without the orchestrator needing to remember to call summarize_task.
  class ReviewTaskAgent < SubAgentTool
    self.sub_agent_class = SubAgents::ReviewTask

    def call(arguments)
      result = super
      if result.is_a?(Hash) && result[:status] == "ok"
        if (summarized_id = auto_summarize_completed_root_task(arguments["task_id"]))
          result[:root_task_summarized] = summarized_id
        end
      end
      result
    end

    private

    def auto_summarize_completed_root_task(task_id)
      task = project.tasks.find_by(id: task_id)
      return unless task
      return if task.root?

      root = task.root_ancestor
      total = root.subtasks.count
      return if total.zero?
      return unless root.subtasks.completed.count == total
      return if root.summary.present?

      SubAgents::SummarizeTask.new(
        role: role,
        arguments: { "task_id" => root.id },
        parent_role_run: resolve_parent_role_run
      ).call

      root.id
    end
  end
end
