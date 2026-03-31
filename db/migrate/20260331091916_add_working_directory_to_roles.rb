class AddWorkingDirectoryToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :working_directory, :string
  end
end
