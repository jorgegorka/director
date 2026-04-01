class RoleTemplatesController < ApplicationController
  before_action :require_company!
  before_action :set_template, only: [ :show, :apply ]

  def index
    @templates = RoleTemplates::Registry.departments
  end

  def show
  end

  def apply
    ceo = ensure_ceo_exists!

    result = RoleTemplates::Applicator.call(
      company: Current.company,
      template_key: @template.key,
      parent_role: ceo
    )

    if result.success?
      redirect_to roles_path, notice: result.summary
    else
      redirect_to role_template_path(@template.key), alert: "Template apply failed: #{result.errors.join(", ")}"
    end
  end

  private

  def ensure_ceo_exists!
    Current.company.roles.find_by(title: RoleTemplates::BulkApplicator::CEO_TITLE) ||
      begin
        RoleTemplates::Applicator.call(
          company: Current.company,
          template_key: RoleTemplates::BulkApplicator::EXECUTIVE_TEMPLATE_KEY
        )
        Current.company.roles.find_by!(title: RoleTemplates::BulkApplicator::CEO_TITLE)
      end
  end

  def set_template
    @template = RoleTemplates::Registry.find(params[:id])
  rescue RoleTemplates::Registry::TemplateNotFound
    raise ActiveRecord::RecordNotFound
  end
end
