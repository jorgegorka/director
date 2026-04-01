class ChangeTaskCreatorToRole < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :tasks, :users, column: :creator_id
    add_foreign_key :tasks, :roles, column: :creator_id

    add_reference :tasks, :reviewed_by, foreign_key: { to_table: :roles }, null: true
    add_column :tasks, :reviewed_at, :datetime
  end
end
