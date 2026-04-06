module Tools
  # Mechanical task-status transitions owned by the assignee. Review
  # decisions (approve/reject) are not handled here -- creators use the
  # `review_task` sub-agent instead, which owns the reasoning for judging
  # submitted work.
  class UpdateTaskStatus < BaseTool
    ALLOWED_STATUSES = %w[in_progress pending_review].freeze

    def name
      "update_task_status"
    end

    def definition
      {
        name: name,
        description: "Change a task's status. As assignee you can set: in_progress, pending_review. To approve or reject a submitted task, use the `review_task` tool instead.",
        inputSchema: {
          type: "object",
          properties: {
            task_id: { type: "integer", description: "ID of the task to update" },
            status: { type: "string", enum: ALLOWED_STATUSES, description: "New status" }
          },
          required: %w[task_id status]
        }
      }
    end

    def call(arguments)
      task = project.tasks.find(arguments["task_id"])
      new_status = arguments["status"]

      unless ALLOWED_STATUSES.include?(new_status)
        raise ArgumentError, "update_task_status only handles #{ALLOWED_STATUSES.join(' and ')}. Use review_task to approve or reject submitted work."
      end

      validate_assignee!(task)
      validate_subtasks_completed!(task) if new_status == "pending_review"

      task.update!(status: new_status)

      { id: task.id, status: task.status }
    end

    private

    def validate_subtasks_completed!(task)
      incomplete = task.subtasks.where.not(status: [ :completed, :cancelled ]).count
      return if incomplete.zero?

      raise ArgumentError, "Cannot submit for review: #{incomplete} subtask(s) are not yet completed"
    end

    def validate_assignee!(task)
      raise ArgumentError, "Only the assignee can update this task's status" unless task.assignee_id == role.id
    end
  end
end
