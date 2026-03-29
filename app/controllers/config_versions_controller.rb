class ConfigVersionsController < ApplicationController
  before_action :require_company!

  def index
    @versionable_type = params[:type]
    @versionable_id = params[:record_id]

    unless @versionable_type.present? && @versionable_id.present?
      redirect_to root_path, alert: "Version history requires a record type and ID."
      return
    end

    @versionable = find_versionable
    unless @versionable
      redirect_to root_path, alert: "Record not found."
      return
    end

    @versions = Current.company.config_versions
                  .where(versionable_type: @versionable_type, versionable_id: @versionable_id)
                  .reverse_chronological
                  .includes(:author)
  end

  def show
    @version = Current.company.config_versions.find(params[:id])
    @versionable = @version.versionable
  end

  def rollback
    @version = Current.company.config_versions.find(params[:id])
    @versionable = @version.versionable

    unless @versionable
      redirect_to root_path, alert: "Cannot rollback -- the original record no longer exists."
      return
    end

    @version.restore!

    AuditEvent.create!(
      auditable: @versionable,
      actor: Current.user,
      action: "config_rollback",
      company: Current.company,
      metadata: { version_id: @version.id }
    )

    redirect_to @versionable, notice: "Configuration rolled back to version from #{@version.created_at.strftime('%b %d, %Y %H:%M')}."
  end

  private

  def find_versionable
    case @versionable_type
    when "Role"
      Current.company.roles.find_by(id: @versionable_id)
    else
      nil
    end
  end
end
