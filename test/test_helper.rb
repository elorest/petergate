ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] ||= "sqlite3::memory:"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"

# Devise is a development dependency, not a runtime one. When it is present a
# single test proves a real Devise app satisfies the authentication contract
# the README documents; when it is absent that test skips.
DEVISE_AVAILABLE = begin
  require "devise"
  # A generated config/initializers/devise.rb does this; the suite has no
  # initializers, so it wires the ORM up itself.
  require "devise/orm/active_record"
  true
rescue LoadError
  false
end

require "petergate"

require "minitest/autorun"
require "action_dispatch/testing/integration"

module Petergate
  # A minimal host application.
  #
  # petergate needs ActiveRecord, ActionController, and three authentication
  # methods that the host app is expected to provide. A full dummy Rails app
  # (and Devise) would only add moving parts that belong to something other
  # than the gem under test, so the suite boots the smallest app that can
  # exercise the real code paths.
  class TestApplication < Rails::Application
    config.root                  = File.expand_path("..", __dir__)
    config.eager_load            = false
    config.secret_key_base       = "petergate-test-key-base-not-a-secret"
    config.logger                = Logger.new(IO::NULL)
    config.load_defaults Rails::VERSION::STRING.to_f

    # Surface real failures instead of a rescued 500 page, and get out of the
    # way of request specs that are not testing Rails' own protections.
    config.consider_all_requests_local              = true
    config.action_dispatch.show_exceptions          = :none
    config.action_controller.allow_forgery_protection = false
    config.hosts.clear

    # Any Rails deprecation is a failure: the point of the suite is to keep
    # petergate clean against current Rails, not merely working.
    config.active_support.deprecation            = :raise
    config.active_support.disallowed_deprecation = :raise
  end

  # Who the next request should be made as. Stands in for a session.
  #
  # Keyed by Devise scope, because petergate can authorize against more than
  # one. Nesting works, since each key is saved and restored independently:
  #
  #   as(customer) { as(vendor, scope: :vendor) { ... } }
  class Session
    class << self
      def resources
        @resources ||= {}
      end

      def current_user
        resources[:user]
      end

      def reset!
        @resources = {}
      end

      def as(resource, scope: :user)
        previous = resources[scope]
        resources[scope] = resource
        yield
      ensure
        resources[scope] = previous
      end
    end
  end
end

Rails.application.initialize!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :multi_role_users, force: true do |t|
    t.string :email
    t.string :roles
  end

  create_table :single_role_users, force: true do |t|
    t.string :email
    t.string :roles
  end

  # A second petergate model, to prove each model gets its own ROLES.
  create_table :accounts, force: true do |t|
    t.string :roles
  end

  # An STI hierarchy: one table, one login, a role vocabulary per subclass.
  create_table :staff, force: true do |t|
    t.string :type
    t.string :email
    t.string :roles
  end

  # A separately authenticated model, for scopes that are not :user.
  create_table :vendors, force: true do |t|
    t.string :email
    t.string :roles
  end

  # Devise-backed models, for the integration tests. `users` carries a type
  # column so an STI subclass can share the one login, and `suppliers` is
  # mapped separately so it has a scope of its own.
  create_table :users, force: true do |t|
    t.string :type
    t.string :email,              null: false, default: ""
    t.string :encrypted_password, null: false, default: ""
    t.string :roles
  end

  create_table :suppliers, force: true do |t|
    t.string :email,              null: false, default: ""
    t.string :encrypted_password, null: false, default: ""
    t.string :roles
  end

  create_table :blogs, force: true do |t|
    t.string :title
    t.text   :content
    t.timestamps
  end
end

require_relative "support/models"
require_relative "support/devise" if DEVISE_AVAILABLE
require_relative "support/authentication"
require_relative "support/controllers"
require_relative "support/routes"

class ActiveSupport::TestCase
  # Rails 7.2 renamed Model.connection to Model.lease_connection, and calling
  # the old name on newer versions is deprecated -- which this suite treats as
  # a failure. Pick whichever the running version offers.
  def connection_for(model)
    model.respond_to?(:lease_connection) ? model.lease_connection : model.connection
  end

  def teardown
    Blog.delete_all
    MultiRoleUser.delete_all
    User.delete_all if defined?(User)
    Supplier.delete_all if defined?(Supplier)
    SingleRoleUser.delete_all
    Account.delete_all
    Staff.delete_all
    Vendor.delete_all
    # An exception raised inside Session.as would otherwise leak the signed-in
    # resource into the next test.
    Petergate::Session.reset!
    super
  end
end

# Request tests drive the full middleware stack, so flash, redirects and
# format negotiation are all exercised for real.
class Petergate::RequestTest < ActionDispatch::IntegrationTest
  self.app = Rails.application

  # Issues the block's requests as `resource`. A nil resource is a signed-out
  # visitor. Pass `scope:` to sign in to something other than :user; nest calls
  # to be signed in to two scopes at once.
  def as(resource, scope: :user, &block)
    Petergate::Session.as(resource, scope: scope, &block)
  end

  # petergate answers js/json/xml requests with a bare status instead of a
  # redirect, so every one of those formats is worth checking.
  def webservice_formats
    [:js, :json, :xml]
  end

  def headers_for(format)
    { "Accept" => Mime[format].to_s, "Content-Type" => Mime[format].to_s }
  end
end
