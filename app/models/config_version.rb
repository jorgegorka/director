class ConfigVersion < ApplicationRecord
  include Tenantable
  include Chronological

  belongs_to :versionable, polymorphic: true
  belongs_to :author, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: %w[create update rollback] }
  validates :snapshot, presence: true
  scope :for_versionable, ->(record) { where(versionable: record) }

  def restore!
    versionable.assign_attributes(restorable_attributes)
    versionable.save!
  end

  def restorable_attributes
    snapshot.except("id", "created_at", "updated_at", "project_id")
  end

  def diff_summary
    changeset.map do |attr, (old_val, new_val)|
      { attribute: attr, from: old_val, to: new_val }
    end
  end
end
