class AddGoalIdToAgents < ActiveRecord::Migration[8.1]
  def change
    add_reference :agents, :goal, null: true, foreign_key: true
  end
end
