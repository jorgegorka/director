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
        if (root_hint = root_task_just_completed_hint(task))
          response[:root_task_completed] = root_hint
        end
        response
      when "reject"
        task.reject_by!(role, feedback: arguments["feedback"])
        { id: task.id, decision: "rejected", status: task.status, feedback: arguments["feedback"] }
      else
        raise ArgumentError, "decision must be 'approve' or 'reject'"
      end
    rescue Tasks::Reviewing::ReviewError => e
      raise ArgumentError, e.message
    end

    private

    # Emitted as a hint in the approval response when this approval was the
    # final piece needed to bring a root task to 100% completion. The
    # orchestrator reads this and calls `summarize_task` to record what was
    # achieved. We count direct subtasks at the root rather than reading
    # root.status because the parent auto-completion runs after this hook.
    def root_task_just_completed_hint(task)
      return nil if task.root?

      root = task.root_ancestor
      total = root.subtasks.count
      return nil if total.zero?
      return nil unless root.subtasks.completed.count == total

      { id: root.id, title: root.title }
    end
  end
end
