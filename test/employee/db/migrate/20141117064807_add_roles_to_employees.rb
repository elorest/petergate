class AddRolesToEmployees < ActiveRecord::Migration[5.2]
  def change
    add_column :employees, :roles, :string
  end
end
