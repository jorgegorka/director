class AddMaxConcurrentAgentsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :max_concurrent_agents, :integer, default: 0, null: false
  end
end
