module Tools
  class ListMyTasks < BaseTool
    def name
      "list_my_tasks"
    end

    def definition
      {
        name: name,
        description: "List tasks assigned to your role, optionally filtered by status.",
        inputSchema: {
          type: "object",
          properties: {
            status: { type: "string", enum: %w[open in_progress blocked completed cancelled pending_review], description: "Filter by status" }
          }
        }
      }
    end

    def call(arguments)
      scope = role.assigned_tasks
      scope = scope.where(status: arguments["status"]) if arguments["status"].present?

      tasks = scope.order(priority: :desc, created_at: :desc).map do |task|
        {
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          goal_id: task.goal_id,
          parent_task_id: task.parent_task_id,
          creator_id: task.creator_id
        }
      end

      { tasks: tasks, count: tasks.size }
    end
  end
end
