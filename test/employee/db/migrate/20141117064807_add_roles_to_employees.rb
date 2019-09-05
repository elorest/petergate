class AddRolesToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :roles, :string
  end
end
