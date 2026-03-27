class CreateConfigVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :config_versions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :versionable, polymorphic: true, null: false
      t.references :author, polymorphic: true
      t.string :action, null: false
      t.jsonb :snapshot, default: {}, null: false
      t.jsonb :changeset, default: {}, null: false
      t.timestamps
    end

    add_index :config_versions, [ :versionable_type, :versionable_id, :created_at ],
              name: "index_config_versions_on_versionable_and_time"
  end
end
