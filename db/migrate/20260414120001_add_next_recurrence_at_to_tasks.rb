class AddNextRecurrenceAtToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :next_recurrence_at, :datetime
    add_index  :tasks, :next_recurrence_at
  end
end
