module Tools
  class ListHirableRoles < BaseTool
    def name
      "list_hirable_roles"
    end

    def definition
      {
        name: name,
        description: "List roles you can hire as subordinates based on your department template.",
        inputSchema: {
          type: "object",
          properties: {}
        }
      }
    end

    def call(_arguments)
      hirable = role.hirable_roles.map do |template_role|
        {
          title: template_role.title,
          description: template_role.description,
          job_spec: template_role.job_spec
        }
      end

      { hirable_roles: hirable, count: hirable.size, auto_hire_enabled: role.auto_hire_enabled? }
    end
  end
end
