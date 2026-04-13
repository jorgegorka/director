class AddRecurrenceToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :recurrence_interval, :integer
    add_column :tasks, :recurrence_unit, :integer
    add_column :tasks, :recurrence_anchor_at, :datetime
    add_column :tasks, :recurrence_last_fired_at, :datetime
    add_column :tasks, :recurrence_timezone, :string
  end
end
