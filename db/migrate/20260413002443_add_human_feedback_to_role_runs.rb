class AddHumanFeedbackToRoleRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :role_runs, :human_feedback, :text
  end
end
