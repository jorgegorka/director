module Tools
  class ListMyGoals < BaseTool
    def name
      "list_my_goals"
    end

    def definition
      {
        name: name,
        description: "List goals assigned to your role.",
        inputSchema: {
          type: "object",
          properties: {}
        }
      }
    end

    def call(arguments)
      goals = role.goals.ordered.map do |goal|
        {
          id: goal.id,
          title: goal.title,
          description: goal.description,
          completion_percentage: goal.completion_percentage,
          parent_id: goal.parent_id
        }
      end

      { goals: goals, count: goals.size }
    end
  end
end
