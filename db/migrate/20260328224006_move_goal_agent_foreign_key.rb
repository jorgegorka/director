class MoveGoalAgentForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_reference :agents, :goal, foreign_key: true
    add_reference :goals, :agent, null: true, foreign_key: true
  end
end
