class RoleTemplatesController < ApplicationController
  before_action :require_project!
  before_action :set_template, only: [ :show, :apply ]

  def index
    @templates = RoleTemplates::Registry.all
  end

  def show
  end

  def apply
    result = RoleTemplates::Applicator.call(
      project: Current.project,
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
    @template = RoleTemplates::Registry.find(params[:id])
  rescue RoleTemplates::Registry::TemplateNotFound
    raise ActiveRecord::RecordNotFound
  end
end
