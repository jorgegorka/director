module RoleLibrary
  class Registry
    class RoleNotFound < StandardError; end
    class InvalidRole < StandardError; end

    LibraryRole = Data.define(:key, :title, :description, :category, :job_spec, :skill_keys)

    class << self
      def all
        load_roles unless @roles
        @roles
      end

      def find(key)
        load_roles unless @index
        role = @index[key.to_s]
        raise RoleNotFound, "Library role not found: #{key}" unless role
        role
      end

      def keys
        load_roles unless @keys
        @keys
      end

      def exists?(key)
        load_roles unless @index
        @index.key?(key.to_s)
      end

      def reset!
        @roles = @index = @keys = nil
      end

      private

      def load_roles
        files = Dir[Rails.root.join("db/seeds/roles/*.yml")].sort
        roles = files.map { |file| load_role(file) }
        @roles = roles.freeze
        @index = roles.index_by(&:key).freeze
        @keys  = roles.map(&:key).freeze
      end

      def load_role(file)
        data = YAML.load_file(file)
        LibraryRole.new(
          key: data.fetch("key"),
          title: data.fetch("title"),
          description: data.fetch("description"),
          category: data.fetch("category"),
          job_spec: data.fetch("job_spec"),
          skill_keys: data.fetch("skill_keys").freeze
        )
      rescue KeyError => e
        raise InvalidRole, "Invalid library role #{File.basename(file)}: missing #{e.message}"
      end
    end
  end
end
