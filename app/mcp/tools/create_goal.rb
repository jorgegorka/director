module Tools
  class CreateGoal < BaseTool
    def name
      "create_goal"
    end

    def definition
      {
        name: name,
        description: "Create a new goal. Optionally nest it under a parent goal and assign it to a role.",
        inputSchema: {
          type: "object",
          properties: {
            title: { type: "string", description: "Goal title" },
            description: { type: "string", description: "Goal description" },
            parent_goal_id: { type: "integer", description: "ID of the parent goal to nest under" },
            role_id: { type: "integer", description: "ID of the role to assign this goal to" },
            position: { type: "integer", description: "Sort position among siblings (default 0)" }
          },
          required: [ "title" ]
        }
      }
    end

    def call(arguments)
      goal = company.goals.new(
        title: arguments["title"],
        description: arguments["description"],
        parent_id: arguments["parent_goal_id"],
        role_id: arguments["role_id"],
        position: arguments["position"] || 0
      )

      goal.save!

      { id: goal.id, title: goal.title, parent_id: goal.parent_id, role_id: goal.role_id, position: goal.position }
    end
  end
end
