require 'securerandom'

module Petergate
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("../templates", __FILE__)

      desc "Copies migrations"
      class_option :orm

      # def copy_initializer
      #   @underscored_user_name = "user".underscore
      #   template '../templates/active_admin.rb.erb',
      #     'config/initializers/active_admin.rb'
      # end

      # def install_assets
      #   require 'rails'
      #   require 'active_admin'

      #   template '../templates/active_admin.js',
      #     'app/assets/javascripts/active_admin.js'
      #   template '../templates/active_admin.css.scss',
      #     'app/assets/stylesheets/active_admin.css.scss'
      # end

      # def setup_routes
      #   route "mount Goldencobra::Engine => '/'"
      #   route "devise_for :users, ActiveAdmin::Devise.config"
      #   route "ActiveAdmin.routes(self)"
      # end

      # def self.source_root
      #   File.expand_path("../templates", __FILE__)
      # end
      #

      def insert_into_user_model
        inject_into_file "app/models/user.rb", after: /^\s{2,}devise[^\n]+\n[^\n]+\n/ do
          <<-'RUBY'

  ################################################################################ 
  ## Roles Code from Petergate.
  ################################################################################

  serialize :roles

  # The :user role is added by default and shouldn't be included in this list.
  Roles = [:admin] 

  after_initialize do
    self[:roles] = []
  end

  def roles=(v)
    self[:roles] = v.map(&:to_sym).to_a.select{|r| r.size > 0 && Roles.include?(r)}
  end

  def roles
    self[:roles] + [:user]
  end

  def role
    roles.first
  end

          RUBY
        end
      end

      def self.next_migration_number(path)
        sleep 1
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_migrations
        Dir["#{self.class.source_root}/migrations/*.rb"].sort.each do |filepath|
          name = File.basename(filepath)
          migration_template "migrations/#{name}", "db/migrate/#{name}"
        end
      end
    end
  end
end
