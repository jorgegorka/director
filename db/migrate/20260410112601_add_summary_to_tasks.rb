class AddSummaryToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :summary, :text
  end
end
