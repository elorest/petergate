require 'securerandom'

module Petergate
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("../templates", __FILE__)

      desc "Sets up rails project for Petergate Authorizations"

      argument :model_name, type: :string, default: "User", banner: "ModelName"
      class_option :table_name, type: :string,
                   desc: "Table to add the roles column to (defaults to the model's table)"

      # Rails' own idiom: a bare timestamp collides when the generator runs
      # twice inside one second, which the old code papered over with a
      # `sleep 1` on every run.
      def self.next_migration_number(dirname)
        # ::ActiveRecord -- inside module Petergate the bare name finds
        # Petergate::ActiveRecord, the mixin namespace.
        ::ActiveRecord::Migration.next_migration_number(current_migration_number(dirname) + 1)
      end

      def insert_into_user_model
        unless File.exist?(File.join(destination_root, model_path))
          raise Thor::Error, "#{model_path} does not exist. Generate the model first, " \
                             "or pass the name of one that does."
        end

        inject_into_file model_path, after: model_declaration_pattern do
          <<-'RUBY'

  ############################################################################################
  ## PeterGate Roles                                                                        ##
  ## The :user role is added by default and shouldn't be included in this list.             ##
  ## Add :root_admin to this list for a role that reaches every action whatever             ##
  ## the access rules say. Nobody can hold it until it is declared here.                    ##
  ## The multiple option can be set to true if you need users to have multiple roles.       ##
  petergate(roles: [:admin, :editor], multiple: false)                                      ##
  ############################################################################################ 
 
          RUBY
        end
      end

  #     def insert_into_application_controller
  #       inject_into_file "app/controllers/application_controller.rb", after: /^class\sApplicationController\s<\sActionController::Base/ do
  #         <<-'RUBY'

  # access(all: [:index, :show])
 
  #         RUBY
  #       end
  #     end

      # The destination filename is the only thing that sets a migration's class
      # name -- Rails derives @migration_class_name from it -- so it has to
      # carry the table name rather than being copied from the template's own.
      def create_migrations
        migration_template "migrations/add_roles_to_users.rb",
                           "db/migrate/add_roles_to_#{roles_table_name}.rb"
      end

      private
        def model_class_name
          model_name.camelize
        end

        # `class Admin::User < ...` declares the demodulized name.
        def bare_class_name
          model_class_name.split("::").last
        end

        def model_path
          File.join("app/models", "#{model_class_name.underscore}.rb")
        end

        # Rails writes a namespaced model either compactly --
        # `class Admin::User < ApplicationRecord` -- or nested inside
        # `module Admin`, where the line reads `class User < ...`. Match both.
        def model_declaration_pattern
          names = [model_class_name, bare_class_name].uniq.map { |n| Regexp.escape(n) }
          /^\s*class\s+(?:#{names.join("|")})\s+<\s+\S+.*$/
        end

        # Ask the model where it actually lives. `Admin::User` is `users` unless
        # the namespace defines a table_name_prefix, and only the class knows
        # which -- `tableize` would guess `admin_users` either way.
        def roles_table_name
          return options[:table_name] if options[:table_name]

          model_class_name.constantize.table_name
        rescue StandardError
          model_class_name.demodulize.tableize
        end
    end
  end
end
