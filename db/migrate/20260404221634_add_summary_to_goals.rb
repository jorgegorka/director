class AddSummaryToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :summary, :text
  end
end
