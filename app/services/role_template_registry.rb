class RoleTemplateRegistry
  class TemplateNotFound < StandardError; end
  class InvalidTemplate < StandardError; end

  Template = Data.define(:key, :name, :description, :roles)
  TemplateRole = Data.define(:title, :description, :job_spec, :parent, :skill_keys)

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
      roles = data.fetch("roles").map do |role_data|
        TemplateRole.new(
          title: role_data.fetch("title"),
          description: role_data.fetch("description"),
          job_spec: role_data.fetch("job_spec"),
          parent: role_data["parent"],
          skill_keys: role_data.fetch("skill_keys")
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

    def validate_parent_ordering!(template)
      seen_titles = Set.new
      template.roles.each do |role|
        if role.parent.present? && !seen_titles.include?(role.parent)
          raise InvalidTemplate,
            "Template '#{template.key}' has invalid parent ordering: " \
            "'#{role.title}' references parent '#{role.parent}' which has not been defined yet. " \
            "Parents must appear before children in the roles array."
        end
        seen_titles << role.title
      end
    end
  end
end
