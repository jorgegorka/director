module RoleTemplates
  class Registry
    class TemplateNotFound < StandardError; end
    class InvalidTemplate < StandardError; end

    Template = Data.define(:key, :name, :description, :roles)
    TemplateRole = Data.define(:role_key, :title, :description, :job_spec, :parent, :skill_keys, :category)

    class << self
      def all
        load_templates unless @templates
        @templates
      end

      def find(key)
        load_templates unless @index
        template = @index[key.to_s]
        raise TemplateNotFound, "Template not found: #{key}" unless template
        template
      end

      def keys
        load_templates unless @keys
        @keys
      end

      def reset!
        @templates = @index = @keys = nil
      end

      private

      def load_templates
        template_files = Dir[Rails.root.join("db/seeds/role_templates/*.yml")].sort
        templates = template_files.map { |file| load_template(file) }
        templates.each { |t| validate_parent_ordering!(t) }
        @templates = templates.freeze
        @index = templates.index_by(&:key).freeze
        @keys = templates.map(&:key).freeze
      end

      def load_template(file)
        data = YAML.load_file(file)
        entries = data.fetch("roles")
        titles_by_role_key = resolve_titles(file, entries)

        roles = entries.map do |entry|
          role_key = entry.fetch("role_key")
          parent_key = entry["parent_key"]
          library_role = fetch_library_role(file, role_key)

          TemplateRole.new(
            role_key: role_key,
            title: library_role.title,
            description: library_role.description,
            job_spec: library_role.job_spec,
            parent: parent_key.present? ? titles_by_role_key.fetch(parent_key) : nil,
            skill_keys: library_role.skill_keys,
            category: library_role.category
          )
        end

        Template.new(
          key: data.fetch("key"),
          name: data.fetch("name"),
          description: data.fetch("description"),
          roles: roles.freeze
        )
      rescue KeyError => e
        raise InvalidTemplate, "Invalid template #{File.basename(file)}: missing #{e.message}"
      end

      def resolve_titles(file, entries)
        entries.each_with_object({}) do |entry, acc|
          role_key = entry.fetch("role_key")
          library_role = fetch_library_role(file, role_key)
          acc[role_key] = library_role.title
        end
      end

      def fetch_library_role(file, role_key)
        RoleLibrary::Registry.find(role_key)
      rescue RoleLibrary::Registry::RoleNotFound
        raise InvalidTemplate,
          "Template #{File.basename(file)} references unknown library role '#{role_key}'. " \
          "Add db/seeds/roles/#{role_key}.yml or fix the reference."
      end

      def validate_parent_ordering!(template)
        seen_role_keys = Set.new
        template.roles.each do |role|
          entry_parent_key = parent_role_key(template, role)
          if entry_parent_key.present? && !seen_role_keys.include?(entry_parent_key)
            raise InvalidTemplate,
              "Template '#{template.key}' has invalid parent ordering: " \
              "'#{role.role_key}' references parent '#{entry_parent_key}' which has not been defined yet. " \
              "Parents must appear before children in the roles array."
          end
          seen_role_keys << role.role_key
        end
      end

      def parent_role_key(template, template_role)
        return nil if template_role.parent.nil?

        match = template.roles.find { |r| r.title == template_role.parent }
        match&.role_key
      end
    end
  end
end
