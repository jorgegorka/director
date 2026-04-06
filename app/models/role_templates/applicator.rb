module RoleTemplates
  class Applicator
    Result = Data.define(:created, :skipped, :errors, :created_roles) do
      def success? = errors.empty?
      def total = created + skipped
      def summary
        parts = []
        parts << "Created #{created} role#{"s" unless created == 1}" if created > 0
        parts << "Skipped #{skipped} existing" if skipped > 0
        parts << "#{errors.size} error#{"s" unless errors.size == 1}" if errors.any?
        parts.join(", ")
      end
    end

    attr_reader :project, :template_key, :parent_role

    def initialize(project:, template_key:, parent_role: nil)
      @project = project
      @template_key = template_key
      @parent_role = parent_role
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def call
      template = RoleTemplates::Registry.find(template_key)
      existing_roles = project.roles.where(title: template.roles.map(&:title)).index_by(&:title)
      all_skill_keys = template.roles.flat_map(&:skill_keys).uniq
      skills_by_key = project.skills.where(key: all_skill_keys).index_by(&:key)
      categories_by_name = project.role_categories.index_by(&:name)

      created = 0
      skipped = 0
      errors = []
      created_roles = []
      roles_by_title = {}

      template.roles.each do |template_role|
        existing = existing_roles[template_role.title]
        if existing
          skipped += 1
          roles_by_title[template_role.title] = existing
          next
        end

        parent = resolve_parent(template_role, roles_by_title)
        role = project.roles.build(
          title: template_role.title,
          description: template_role.description,
          job_spec: template_role.job_spec,
          parent: parent,
          role_category: categories_by_name[template_role.category]
        )

        if role.save
          created += 1
          created_roles << role
          roles_by_title[template_role.title] = role
          assign_skills(role, template_role.skill_keys, skills_by_key)
        else
          errors << "#{template_role.title}: #{role.errors.full_messages.join(", ")}"
        end
      end

      Result.new(created: created, skipped: skipped, errors: errors.freeze, created_roles: created_roles.freeze)
    end

    private

    def resolve_parent(template_role, roles_by_title)
      if template_role.parent.nil?
        parent_role
      else
        roles_by_title[template_role.parent]
      end
    end

    def assign_skills(role, skill_keys, skills_by_key)
      return if skill_keys.empty?

      records = skill_keys.filter_map { |key| { role_id: role.id, skill_id: skills_by_key[key]&.id } if skills_by_key[key] }
      RoleSkill.insert_all(records) if records.any?
    end
  end
end
