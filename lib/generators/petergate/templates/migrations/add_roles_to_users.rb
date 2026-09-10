class <%= migration_class_name %> < ActiveRecord::Migration<%= Rails::VERSION::MAJOR >= 5 ? "[#{Rails.version.to_f}]" : "" %>
  def change
    add_column :<%= roles_table_name %>, :roles, :string
  end
end
