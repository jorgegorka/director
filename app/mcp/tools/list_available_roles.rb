module Tools
  class ListAvailableRoles < BaseTool
    def name
      "list_available_roles"
    end

    def definition
      {
        name: name,
        description: "List roles you can assign tasks to (subordinates and siblings in the org chart).",
        inputSchema: {
          type: "object",
          properties: {}
        }
      }
    end

    def call(_arguments)
      subordinates = company.roles.active.where(id: role.descendant_ids)
      siblings = if role.parent_id.present?
        company.roles.active.where(parent_id: role.parent_id).where.not(id: role.id)
      else
        Role.none
      end

      available = (subordinates + siblings).uniq.map do |r|
        {
          id: r.id,
          title: r.title,
          description: r.description,
          relationship: role.descendant_ids.include?(r.id) ? "subordinate" : "sibling",
          status: r.status,
          agent_configured: r.agent_configured?
        }
      end

      { roles: available, count: available.size }
    end
  end
end
