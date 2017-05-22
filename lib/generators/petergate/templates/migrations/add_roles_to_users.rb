class AddRolesToUsers < ActiveRecord::Migration<%= Rails::VERSION::MAJOR >= 5 ? "[#{Rails.version.to_f}]" : "" %>
  def change
    add_column :users, :roles, :string
  end
end
