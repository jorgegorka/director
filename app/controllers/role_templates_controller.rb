class RoleTemplatesController < ApplicationController
  before_action :require_company!
  before_action :set_template, only: [ :show, :apply ]

  def index
    @templates = RoleTemplateRegistry.all
  end

  def show
  end

  def apply
    result = ApplyRoleTemplateService.call(
      company: Current.company,
      template_key: @template.key
    )

    if result.success?
      redirect_to roles_path, notice: result.summary
    else
      redirect_to role_template_path(@template.key), alert: "Template apply failed: #{result.errors.join(", ")}"
    end
  end

  private

  def set_template
    @template = RoleTemplateRegistry.find(params[:id])
  rescue RoleTemplateRegistry::TemplateNotFound
    raise ActiveRecord::RecordNotFound
  end
end
