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

# A namespace whose models do not live where `tableize` would guess:
# Warehouse::Item is `warehouse_items`, while the demodulized fallback answers
# `items`. Defined as a real constant so `constantize` in the generator
# resolves -- without one, every namespaced case falls through to the rescue
# and the two branches cannot be told apart.
module Warehouse
  def self.table_name_prefix
    "warehouse_"
  end

  # No table backing it, and none needed: table_name is derived, not queried.
  class Item < ActiveRecord::Base
  end
end

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

  def test_it_configures_a_named_model_instead_of_user
    File.write File.join(destination_root, "app/models/worker.rb"), <<~RUBY
      class Worker < ApplicationRecord
      end
    RUBY

    run_generator %w[Worker]

    assert_file "app/models/worker.rb" do |model|
      assert_match(/petergate\(roles: \[:admin, :editor\], multiple: false\)/, model)
    end
    # The default model is left alone.
    assert_file("app/models/user.rb") { |model| refute_match(/petergate/, model) }
  end

  def test_a_named_models_migration_carries_its_own_table_and_class
    File.write File.join(destination_root, "app/models/worker.rb"), <<~RUBY
      class Worker < ApplicationRecord
      end
    RUBY

    run_generator %w[Worker]

    assert_migration "db/migrate/add_roles_to_workers.rb" do |migration|
      assert_match(/class AddRolesToWorkers < ActiveRecord::Migration/, migration)
      assert_match(/add_column :workers, :roles, :string/, migration)
    end
  end

  def test_the_table_name_can_be_overridden
    File.write File.join(destination_root, "app/models/worker.rb"), <<~RUBY
      class Worker < ApplicationRecord
      end
    RUBY

    run_generator %w[Worker --table-name=staff]

    assert_migration "db/migrate/add_roles_to_staff.rb" do |migration|
      assert_match(/add_column :staff, :roles, :string/, migration)
    end
  end

  def test_it_configures_a_namespaced_model_written_compactly
    # Rails' own model generator emits `class Admin::User < ApplicationRecord`,
    # which an anchor built from the demodulized name never matches.
    mkdir_p File.join(destination_root, "app/models/admin")
    File.write File.join(destination_root, "app/models/admin/user.rb"), <<~RUBY
      class Admin::User < ApplicationRecord
      end
    RUBY

    run_generator %w[Admin::User]

    assert_file "app/models/admin/user.rb" do |model|
      assert_match(/petergate\(roles: \[:admin, :editor\], multiple: false\)/, model)
    end
  end

  def test_it_configures_a_namespaced_model_written_nested
    mkdir_p File.join(destination_root, "app/models/admin")
    File.write File.join(destination_root, "app/models/admin/user.rb"), <<~RUBY
      module Admin
        class User < ApplicationRecord
        end
      end
    RUBY

    run_generator %w[Admin::User]

    assert_file "app/models/admin/user.rb" do |model|
      assert_match(/petergate\(roles: \[:admin, :editor\], multiple: false\)/, model)
    end
  end

  # No Admin::User constant exists in this process, so `constantize` raises and
  # this covers the rescue in roles_table_name. The branch above it -- asking
  # the class -- is covered by Warehouse::Item below, where the two answers
  # differ. Together they pin which branch runs.
  def test_a_namespaced_models_migration_falls_back_to_the_demodulized_table
    # Admin::User lives in `users` unless the namespace sets a table_name_prefix.
    # `tableize` would guess `admin_users`, and the migration would fail.
    mkdir_p File.join(destination_root, "app/models/admin")
    File.write File.join(destination_root, "app/models/admin/user.rb"), <<~RUBY
      class Admin::User < ApplicationRecord
      end
    RUBY

    run_generator %w[Admin::User]

    assert_migration "db/migrate/add_roles_to_users.rb" do |migration|
      assert_match(/add_column :users, :roles, :string/, migration)
    end
  end

  def test_a_namespaced_model_is_asked_for_its_table_rather_than_guessed
    mkdir_p File.join(destination_root, "app/models/warehouse")
    File.write File.join(destination_root, "app/models/warehouse/item.rb"), <<~RUBY
      class Warehouse::Item < ApplicationRecord
      end
    RUBY

    run_generator %w[Warehouse::Item]

    # Warehouse sets a table_name_prefix, so the class answers `warehouse_items`
    # where the demodulized fallback would answer `items`. Asserting the prefix
    # is what distinguishes the two.
    assert_migration "db/migrate/add_roles_to_warehouse_items.rb" do |migration|
      assert_match(/add_column :warehouse_items, :roles, :string/, migration)
    end
  end

  def test_two_runs_in_the_same_second_do_not_collide
    File.write File.join(destination_root, "app/models/worker.rb"), <<~RUBY
      class Worker < ApplicationRecord
      end
    RUBY

    run_generator                 # User
    run_generator %w[Worker]    # immediately after

    versions = Dir[File.join(destination_root, "db/migrate/*.rb")]
               .map { |path| File.basename(path)[/\A\d+/] }

    assert_equal 2, versions.size
    assert_equal versions.uniq.size, versions.size, "migration versions collided"
  end

  def test_it_refuses_a_model_that_does_not_exist
    # Thor reports the error rather than letting it escape, so the observable
    # result is the message plus nothing written.
    output = capture(:stderr) { run_generator %w[Nonexistent] }

    assert_match(%r{app/models/nonexistent\.rb}, output)
    assert_no_migration "db/migrate/add_roles_to_nonexistents.rb"
  end

  def test_running_the_installer_twice_does_not_duplicate_the_roles_block
    run_generator
    run_generator
    model = File.read(File.join(destination_root, "app/models/user.rb"))
    assert_equal 1, model.scan(/petergate\(roles:/).size,
                 "expected the petergate block to appear exactly once"
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
      assert_match(/render :new, status: 422/, controller)
      assert_match(/render :edit, status: 422/, controller)
      assert_match(/notice: .*, status: :see_other/, controller)

      # Neither symbol spans the Rack versions this template has to serve:
      # 2.2 knows only :unprocessable_entity, 3.2 only :unprocessable_content,
      # and 3.2 warns on the former. The numeric literal avoids the question.
      refute_match(/unprocessable_entity/, controller)
      refute_match(/unprocessable_content/, controller)
    end
  end

  def test_generated_controllers_are_valid_ruby
    run_generator %w[Gadget name:string]
    path = File.join(destination_root, "app/controllers/gadgets_controller.rb")
    assert system("ruby", "-c", path, out: File::NULL, err: File::NULL),
           "generated controller is not valid Ruby"
  end
  def test_it_generates_namespaced_controllers
    run_generator %w[Admin::Gadget name:string]
    assert_file "app/controllers/admin/gadgets_controller.rb" do |controller|
      # Rails emits the compact form for a namespaced resource; the `module`
      # wrapper only appears when the application itself is namespaced.
      assert_match(/class Admin::GadgetsController < ApplicationController/, controller)
      assert_match(/^  access /, controller)
      assert_match(/def admin_gadget_params/, controller)
      # require_dependency was a classic-autoloader crutch; Zeitwerk needs none.
      refute_match(/require_dependency/, controller)
    end
  end

  def test_namespaced_controllers_are_valid_ruby
    run_generator %w[Admin::Gadget name:string]
    path = File.join(destination_root, "app/controllers/admin/gadgets_controller.rb")
    assert system("ruby", "-c", path, out: File::NULL, err: File::NULL),
           "generated namespaced controller is not valid Ruby"
  end
end
