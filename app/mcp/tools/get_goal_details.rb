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
      goal = company.goals.find(arguments["goal_id"])

      ancestry = goal.ancestry_chain.map do |g|
        { id: g.id, title: g.title }
      end

      children = goal.children.ordered.map do |child|
        { id: child.id, title: child.title, progress_percentage: child.progress_percentage }
      end

      tasks = goal.tasks.includes(:assignee, :creator).map do |task|
        { id: task.id, title: task.title, status: task.status, assignee_title: task.assignee&.title }
      end

      {
        id: goal.id,
        title: goal.title,
        description: goal.description,
        role_id: goal.role_id,
        progress_percentage: goal.progress_percentage,
        is_mission: goal.mission?,
        ancestry: ancestry,
        children: children,
        tasks: tasks
      }
    end
  end
end
