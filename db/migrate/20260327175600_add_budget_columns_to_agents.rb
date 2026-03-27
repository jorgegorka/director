class AddBudgetColumnsToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :budget_cents, :integer           # monthly budget in cents, nil = no budget set
    add_column :agents, :budget_period_start, :date       # start of current budget period, nil = no period active
  end
end
