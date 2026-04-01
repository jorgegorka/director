module RoleTemplates
  class BulkApplicator
    EXECUTIVE_TEMPLATE_KEY = "executive"
    CEO_TITLE = "CEO"

    attr_reader :company

    def initialize(company:)
      @company = company
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def call
      executive_result = RoleTemplates::Applicator.call(
        company: company,
        template_key: EXECUTIVE_TEMPLATE_KEY
      )

      ceo = company.roles.find_by!(title: CEO_TITLE)

      total_created = executive_result.created
      total_skipped = executive_result.skipped
      total_errors = executive_result.errors.dup
      all_created_roles = executive_result.created_roles.dup

      department_keys.each do |key|
        result = RoleTemplates::Applicator.call(
          company: company,
          template_key: key,
          parent_role: ceo
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

    private

    def department_keys
      RoleTemplates::Registry.keys - [ EXECUTIVE_TEMPLATE_KEY ]
    end
  end
end
