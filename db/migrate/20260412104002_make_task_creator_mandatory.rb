class MakeTaskCreatorMandatory < ActiveRecord::Migration[8.1]
  def change
    change_column_null :tasks, :creator_id, false
  end
end
