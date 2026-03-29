class ApplyAllRoleTemplatesService
  CEO_TITLE = "CEO"
  CEO_DESCRIPTION = "Chief Executive Officer who sets company vision, approves budgets, and drives strategic direction."
  CEO_JOB_SPEC = "Set the overall strategic direction for the company. " \
    "Make key decisions on resource allocation, partnerships, and growth priorities. " \
    "Oversee all department heads and ensure alignment across the organization."

  attr_reader :company

  def initialize(company:)
    @company = company
  end

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def call
    ceo = find_or_create_ceo
    total_created = ceo_was_created? ? 1 : 0
    total_skipped = ceo_was_created? ? 0 : 1
    total_errors = []
    all_created_roles = ceo_was_created? ? [ ceo ] : []

    RoleTemplateRegistry.keys.each do |key|
      result = ApplyRoleTemplateService.call(
        company: company,
        template_key: key,
        parent_role: ceo
      )
      total_created += result.created
      total_skipped += result.skipped
      total_errors.concat(result.errors)
      all_created_roles.concat(result.created_roles)
    end

    ApplyRoleTemplateService::Result.new(
      created: total_created,
      skipped: total_skipped,
      errors: total_errors.freeze,
      created_roles: all_created_roles.freeze
    )
  end

  private

  def find_or_create_ceo
    existing = company.roles.find_by(title: CEO_TITLE)
    if existing
      @ceo_was_created = false
      existing
    else
      role = company.roles.create!(
        title: CEO_TITLE,
        description: CEO_DESCRIPTION,
        job_spec: CEO_JOB_SPEC
      )
      @ceo_was_created = true
      role
    end
  end

  def ceo_was_created?
    @ceo_was_created
  end
end
