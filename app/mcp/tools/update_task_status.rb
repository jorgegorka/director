module Tools
  class UpdateTaskStatus < BaseTool
    def name
      "update_task_status"
    end

    def definition
      {
        name: name,
        description: "Change a task's status. As assignee you can set: in_progress, pending_review. As creator you can approve (completed) or reject (open, with feedback).",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the task to update" },
            status: { type: "string", enum: %w[in_progress pending_review completed open], description: "New status" },
            feedback: { type: "string", description: "Feedback message when rejecting (setting status to open)" }
          },
          required: %w[task_id status]
        }
      }
    end

    def call(arguments)
      task = company.tasks.find(arguments["task_id"])
      new_status = arguments["status"]

      validate_permission!(task, new_status)
      validate_subtasks_completed!(task) if new_status == "pending_review"

      if new_status == "completed"
        task.update!(status: :completed, reviewed_by: role, reviewed_at: Time.current)
      elsif new_status == "open" && arguments["feedback"].present?
        task.update!(status: :open)
        task.messages.create!(
          author: role,
          body: arguments["feedback"],
          message_type: :comment
        )
      else
        task.update!(status: new_status)
      end

      { id: task.id, status: task.status }
    end

    private

    def validate_subtasks_completed!(task)
      incomplete = task.subtasks.where.not(status: [ :completed, :cancelled ]).count
      return if incomplete.zero?

      raise ArgumentError, "Cannot submit for review: #{incomplete} subtask(s) are not yet completed"
    end

    def validate_permission!(task, new_status)
      case new_status
      when "in_progress"
        raise ArgumentError, "Only the assignee can start a task" unless task.assignee_id == role.id
      when "pending_review"
        raise ArgumentError, "Only the assignee can submit for review" unless task.assignee_id == role.id
      when "completed"
        raise ArgumentError, "Only the creator can approve a task" unless task.creator_id == role.id
      when "open"
        raise ArgumentError, "Only the creator can reject a task" unless task.creator_id == role.id
      end
    end
  end
end
