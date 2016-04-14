require 'securerandom'

module Petergate
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("../templates", __FILE__)
      class_option :orm

      desc "Sets up rails project for Petergate Authorizations"
      def self.next_migration_number(path)
        sleep 1
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def insert_into_user_model
        inject_into_file "app/models/user.rb", after: /^class\sUser < ActiveRecord::Base/ do
          <<-'RUBY'

  ############################################################################################
  ## PeterGate Roles                                                                        ##
  ## The :user role is added by default and shouldn't be included in this list.             ##
  ## The :root_admin can access any page regardless of access settings. Use with caution!  ##
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

      def create_migrations
        Dir["#{self.class.source_root}/migrations/*.rb"].sort.each do |filepath|
          name = File.basename(filepath)
          migration_template "migrations/#{name}", "db/migrate/#{name}"
        end
      end
    end
  end
end
