module Tools
  class GetGoalDetails < BaseTool
    def name
      "get_goal_details"
    end

    def definition
      {
        name: name,
        description: "Get goal details including hierarchy, progress, and linked tasks.",
        inputSchema: {
          type: "object",
          properties: {
            goal_id: { type: "integer", description: "ID of the goal" }
          },
          required: [ "goal_id" ]
        }
      }
    end

    def call(arguments)
      goal = project.goals.find(arguments["goal_id"])

      tasks = goal.tasks.includes(:assignee, :creator).map do |task|
        { id: task.id, title: task.title, status: task.status, assignee_title: task.assignee&.title }
      end

      {
        id: goal.id,
        title: goal.title,
        description: goal.description,
        role_id: goal.role_id,
        completion_percentage: goal.completion_percentage,
        tasks: tasks
      }
    end
  end
end
