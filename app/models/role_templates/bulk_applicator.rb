module RoleTemplates
  class BulkApplicator
    attr_reader :project

    def initialize(project:)
      @project = project
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def call
      total_created = 0
      total_skipped = 0
      total_errors = []
      all_created_roles = []

      RoleTemplates::Registry.keys.each do |key|
        result = RoleTemplates::Applicator.call(
          project: project,
          template_key: key
        )
        total_created += result.created
        total_skipped += result.skipped
        total_errors.concat(result.errors)
        all_created_roles.concat(result.created_roles)
      end

      RoleTemplates::Applicator::Result.new(
        created: total_created,
        skipped: total_skipped,
        errors: total_errors.freeze,
        created_roles: all_created_roles.freeze
      )
    end
  end
end
