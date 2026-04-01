module Tools
  class UpdateGoal < BaseTool
    def name
      "update_goal"
    end

    def definition
      {
        name: name,
        description: "Update a goal's details. The assigned role or any ancestor role can update the goal.",
        inputSchema: {
          type: "object",
          properties: {
            goal_id: { type: "integer", description: "ID of the goal to update" },
            title: { type: "string", description: "New title" },
            description: { type: "string", description: "New description" },
            role_id: { type: "integer", description: "ID of the role to assign/reassign this goal to" },
            completion_percentage: { type: "integer", description: "Completion percentage (0-100). Normally auto-calculated from tasks; set only for goals without tasks." }
          },
          required: [ "goal_id" ]
        }
      }
    end

    def call(arguments)
      goal = company.goals.find(arguments["goal_id"])

      validate_permission!(goal)

      attrs = {}
      attrs[:title] = arguments["title"] if arguments.key?("title")
      attrs[:description] = arguments["description"] if arguments.key?("description")
      attrs[:role_id] = arguments["role_id"] if arguments.key?("role_id")
      attrs[:completion_percentage] = arguments["completion_percentage"] if arguments.key?("completion_percentage")

      goal.update!(attrs)

      {
        id: goal.id,
        title: goal.title,
        description: goal.description,
        role_id: goal.role_id,
        completion_percentage: goal.completion_percentage
      }
    end

    private

    def validate_permission!(goal)
      return if goal.role_id.nil?
      return if goal.role_id == role.id
      return if goal.role.ancestors.any? { |ancestor| ancestor.id == role.id }

      raise ArgumentError, "You do not have permission to update this goal"
    end
  end
end
