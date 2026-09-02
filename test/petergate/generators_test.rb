require "test_helper"
require "rails/generators"

# Rails reads Rails::Generators.templates_path in Generators::Base.inherited,
# so a generator class picks up template overrides only if the path is already
# configured when the class is defined. Booting an app does this before any
# generator loads; the suite has to do the same, before the requires below.
Rails::Generators.configure!(Rails.application.config.generators)

require "rails/generators/test_case"
require "generators/petergate/install_generator"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Petergate::Generators::InstallGenerator
  destination File.expand_path("../../tmp/install_generator", __dir__)
  setup :prepare_destination

  setup do
    mkdir_p File.join(destination_root, "app/models")
    File.write File.join(destination_root, "app/models/user.rb"), <<~RUBY
      class User < ApplicationRecord
      end
    RUBY
  end

  def test_it_configures_the_user_model
    run_generator
    assert_file "app/models/user.rb" do |model|
      assert_match(/petergate\(roles: \[:admin, :editor\], multiple: false\)/, model)
      assert_match(/PeterGate Roles/, model)
    end
  end

  def test_it_creates_the_roles_migration
    run_generator
    assert_migration "db/migrate/add_roles_to_users.rb" do |migration|
      assert_match(/class AddRolesToUsers < ActiveRecord::Migration\[#{Rails.version.to_f}\]/, migration)
      assert_match(/add_column :users, :roles, :string/, migration)
    end
  end

  def test_the_generated_migration_is_valid_ruby
    run_generator
    migration = Dir[File.join(destination_root, "db/migrate/*_add_roles_to_users.rb")].first
    assert migration, "expected a migration to be generated"
    assert system("ruby", "-c", migration, out: File::NULL, err: File::NULL),
           "generated migration is not valid Ruby"
  end
end

# petergate's railtie overrides Rails' scaffold_controller template so generated
# controllers arrive with an `access` line already in place.
class ScaffoldTemplateTest < Rails::Generators::TestCase
  tests Rails::Generators::ScaffoldControllerGenerator
  destination File.expand_path("../../tmp/scaffold_generator", __dir__)
  setup :prepare_destination

  setup do
    # The scaffold generator also wants to add a route.
    mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n"
  end

  def test_the_railtie_puts_petergates_template_on_the_lookup_path
    assert Rails::Generators.templates_path.any? { |path| path.include?("petergate") },
           "expected petergate's lib/templates to be on the generator template path"
  end

  def test_generated_controllers_declare_access_rules
    run_generator %w[Gadget name:string]
    assert_file "app/controllers/gadgets_controller.rb" do |controller|
      assert_match(/^  access /, controller)
    end
  end

  def test_generated_controllers_use_the_status_codes_turbo_needs
    run_generator %w[Gadget name:string]
    assert_file "app/controllers/gadgets_controller.rb" do |controller|
      assert_match(/render :new, status: :unprocessable_entity/, controller)
      assert_match(/render :edit, status: :unprocessable_entity/, controller)
      assert_match(/notice: .*, status: :see_other/, controller)
    end
  end

  def test_generated_controllers_are_valid_ruby
    run_generator %w[Gadget name:string]
    path = File.join(destination_root, "app/controllers/gadgets_controller.rb")
    assert system("ruby", "-c", path, out: File::NULL, err: File::NULL),
           "generated controller is not valid Ruby"
  end
end
