module Tools
  class HireRole < BaseTool
    def name
      "hire_role"
    end

    def definition
      {
        name: name,
        description: "Hire a new subordinate role from your department template. Use list_hirable_roles first to see available options.",
        inputSchema: {
          type: "object",
          properties: {
            template_role_title: { type: "string", description: "Title of the role to hire (must match a hirable role from list_hirable_roles)" },
            budget_cents: { type: "integer", description: "Monthly budget in cents to allocate to the new role" }
          },
          required: %w[template_role_title budget_cents]
        }
      }
    end

    def call(arguments)
      result = role.hire!(
        template_role_title: arguments["template_role_title"],
        budget_cents: arguments["budget_cents"].to_i
      )

      if result.is_a?(Role)
        { status: "hired", role_id: result.id, title: result.title, message: "Successfully hired #{result.title}" }
      else
        { status: "pending_approval", pending_hire_id: result.id, message: "Hire request for #{result.template_role_title} requires admin approval" }
      end
    rescue Roles::Hiring::HiringError => e
      raise ArgumentError, e.message
    end
  end
end
