class RemoveParentIdFromGoals < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :goals, column: :parent_id
    remove_index :goals, name: "index_goals_on_company_id_and_parent_id"
    remove_index :goals, name: "index_goals_on_parent_id"
    remove_column :goals, :parent_id, :bigint
  end
end
