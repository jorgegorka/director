class AddAutoHireEnabledToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :auto_hire_enabled, :boolean, default: false, null: false
  end
end
