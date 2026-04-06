module ConfigVersioned
  extend ActiveSupport::Concern

  included do
    has_many :config_versions, as: :versionable, dependent: :destroy

    after_save :create_config_version, if: :should_version?
  end

  # Subclasses override to specify which attributes to track
  def versionable_attributes
    attributes.except("created_at", "updated_at")
  end

  # Subclasses override to specify which attribute changes trigger versioning
  def governance_attributes
    versionable_attributes.keys
  end

  def version_history
    config_versions.reverse_chronological
  end

  def rollback_to!(version)
    version.restore!
    record_rollback_version(version)
  end

  private

  def should_version?
    return false unless persisted?
    return false if saved_changes.keys == [ "updated_at" ]

    (saved_changes.keys - [ "updated_at" ]).any? { |attr| governance_attributes.include?(attr) }
  end

  def create_config_version
    project = try(:project) || Current.project
    return unless project

    ConfigVersion.create!(
      project: project,
      versionable: self,
      author: Current.user,
      action: previously_new_record? ? "create" : "update",
      snapshot: versionable_attributes,
      changeset: version_changeset
    )
  end

  def record_rollback_version(source_version)
    project = try(:project) || Current.project
    return unless project

    ConfigVersion.create!(
      project: project,
      versionable: self,
      author: Current.user,
      action: "rollback",
      snapshot: versionable_attributes,
      changeset: { "_rollback_source" => source_version.id }
    )
  end

  def version_changeset
    saved_changes.except("updated_at", "created_at")
  end
end
