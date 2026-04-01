class AddCompletionPercentageToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :completion_percentage, :integer, default: 0, null: false
  end
end
