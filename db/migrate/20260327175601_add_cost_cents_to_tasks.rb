class AddCostCentsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :cost_cents, :integer              # cost of this task in cents, nil = no cost recorded
  end
end
