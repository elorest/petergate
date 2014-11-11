require 'securerandom'

module Goldencobra
  module Generators
    class InstallGenerator < Rails::Generators::Base
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

      def create_migrations
        Dir["#{self.class.source_root}/migrations/*.rb"].sort.each do
          |filepath|
          name = File.basename(filepath)
          template "migrations/#{name}", "db/migrate/#{name}"
          sleep 1
        end
      end
    end
  end
end
