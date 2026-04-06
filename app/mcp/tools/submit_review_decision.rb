module Tools
  # Internal tool exposed only inside the `sub_agent_review_task` MCP scope.
  # The review sub-agent is the only client -- the orchestrator never sees
  # this tool, because review decisions must flow through the review
  # specialist rather than being made inline.
  class SubmitReviewDecision < BaseTool
    def name
      "submit_review_decision"
    end

    def definition
      {
        name: name,
        description: "Submit the final review decision for this task. Call exactly once, then stop.",
        inputSchema: {
          type: "object",
          properties: {
            task_id:  { type: "integer", description: "ID of the task being reviewed" },
            decision: { type: "string", enum: %w[approve reject], description: "approve or reject" },
            feedback: { type: "string", description: "Required when rejecting; optional when approving." }
          },
          required: %w[task_id decision]
        }
      }
    end

    def call(arguments)
      task = project.tasks.find(arguments["task_id"])

      case arguments["decision"]
      when "approve"
        task.approve_by!(role)
        response = { id: task.id, decision: "approved", status: task.status }
        if (goal_hint = goal_just_completed_hint(task))
          response[:goal_completed] = goal_hint
        end
        response
      when "reject"
        task.reject_by!(role, feedback: arguments["feedback"])
        { id: task.id, decision: "rejected", status: task.status, feedback: arguments["feedback"] }
      else
        raise ArgumentError, "decision must be 'approve' or 'reject'"
      end
    rescue Task::ReviewError => e
      raise ArgumentError, e.message
    end

    private

    # Emitted as a hint in the approval response when this approval was the
    # final piece needed to bring a goal to 100% completion. The orchestrator
    # reads this and calls `summarize_goal` to record what was achieved. We
    # compute counts directly because Goal#completion_percentage is updated
    # asynchronously by RecalculateGoalCompletionJob.
    def goal_just_completed_hint(task)
      goal = task.goal
      return nil unless goal

      total = goal.tasks.count
      return nil if total.zero?

      completed = goal.tasks.completed.count
      return nil unless total == completed

      { id: goal.id, title: goal.title }
    end
  end
end
