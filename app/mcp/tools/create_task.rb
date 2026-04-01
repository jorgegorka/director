module Tools
  class CreateTask < BaseTool
    def name
      "create_task"
    end

    def definition
      {
        name: name,
        description: "Create a new task and optionally assign it to a role. Assignee must be a subordinate or sibling of your role.",
        inputSchema: {
          type: "object",
          properties: {
            title: { type: "string", description: "Task title" },
            description: { type: "string", description: "Task description" },
            priority: { type: "string", enum: %w[low medium high urgent], description: "Task priority" },
            assignee_role_id: { type: "integer", description: "ID of the role to assign this task to" },
            goal_id: { type: "integer", description: "ID of the goal this task advances" },
            parent_task_id: { type: "integer", description: "ID of the parent task for subtask creation" }
          },
          required: [ "title" ]
        }
      }
    end

    def call(arguments)
      task = company.tasks.new(
        title: arguments["title"],
        description: arguments["description"],
        priority: arguments["priority"] || "medium",
        creator: role,
        assignee_id: arguments["assignee_role_id"],
        goal_id: arguments["goal_id"],
        parent_task_id: arguments["parent_task_id"]
      )

      task.save!

      { id: task.id, title: task.title, status: task.status, assignee_id: task.assignee_id }
    end
  end
end
