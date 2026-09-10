require "test_helper"

# The role API that `petergate(...)` adds to a model.
class RolesTest < ActiveSupport::TestCase
  ##############################################################################
  # ROLES constant
  ##############################################################################

  def test_roles_constant_lists_the_configured_roles_plus_user
    assert_equal [:root_admin, :company_admin, :user], MultiRoleUser::ROLES
  end

  def test_each_model_gets_its_own_roles_constant
    # Regression: the guard used to read `defined?(User::ROLES)`, so once any
    # User class had ROLES, every other petergate model silently went without.
    assert_equal [:supervisor, :user], Account::ROLES
    refute_equal MultiRoleUser::ROLES, Account::ROLES
  end

  def test_user_role_is_not_duplicated_when_configured_explicitly
    assert_equal 1, MultiRoleUser::ROLES.count(:user)
  end

  def test_available_roles_is_readable_from_an_instance
    assert_equal MultiRoleUser::ROLES, MultiRoleUser.new.available_roles
  end

  ##############################################################################
  # Defaults
  ##############################################################################

  def test_a_new_record_defaults_to_the_user_role
    assert_equal [:user], MultiRoleUser.new.roles
    assert_equal [:user], SingleRoleUser.new.roles
  end

  def test_a_record_with_no_stored_roles_reads_as_user
    user = MultiRoleUser.create!(email: "a@example.com")
    assert_equal [:user], user.reload.roles
  end

  ##############################################################################
  # Multiple roles
  ##############################################################################

  def test_multiple_assigns_several_roles_and_always_keeps_user
    user = MultiRoleUser.new(roles: [:root_admin, :company_admin])
    assert_equal [:root_admin, :company_admin, :user], user.roles
  end

  def test_multiple_rejects_roles_that_are_not_configured
    user = MultiRoleUser.new(roles: [:root_admin, :intruder])
    assert_equal [:root_admin, :user], user.roles
  end

  def test_multiple_rejects_blank_roles
    user = MultiRoleUser.new(roles: [:root_admin, :"", nil])
    assert_equal [:root_admin, :user], user.roles
  end

  def test_multiple_accepts_strings
    user = MultiRoleUser.new(roles: ["root_admin"])
    assert_equal [:root_admin, :user], user.roles
  end

  def test_multiple_does_not_duplicate_a_repeated_role
    user = MultiRoleUser.new(roles: [:root_admin, :root_admin])
    assert_equal [:root_admin, :user], user.roles
  end

  def test_multiple_round_trips_symbols_through_the_database
    MultiRoleUser.create!(email: "a@example.com", roles: [:company_admin])
    assert_equal [:company_admin, :user], MultiRoleUser.first.reload.roles
  end

  def test_multiple_stores_roles_as_a_yaml_array
    MultiRoleUser.create!(email: "a@example.com", roles: [:company_admin])
    raw = connection_for(MultiRoleUser).select_value("select roles from multi_role_users limit 1")
    assert_equal "---\n- :company_admin\n- :user\n", raw
  end

  ##############################################################################
  # Single role
  ##############################################################################

  def test_single_assigns_one_role
    assert_equal [:root_admin, :user], SingleRoleUser.new(roles: :root_admin).roles
  end

  def test_single_takes_the_first_role_from_an_array
    assert_equal [:root_admin, :user], SingleRoleUser.new(roles: [:root_admin, :company_admin]).roles
  end

  def test_single_accepts_a_string
    assert_equal [:company_admin, :user], SingleRoleUser.new(roles: "company_admin").roles
  end

  def test_single_falls_back_to_user_for_an_unconfigured_role
    assert_equal [:user], SingleRoleUser.new(roles: :intruder).roles
  end

  def test_single_falls_back_to_user_for_a_blank_assignment
    assert_equal [:user], SingleRoleUser.new(roles: nil).roles
    assert_equal [:user], SingleRoleUser.new(roles: []).roles
    assert_equal [:user], SingleRoleUser.new(roles: "").roles
  end

  def test_single_stores_the_role_as_a_plain_string
    SingleRoleUser.create!(email: "a@example.com", roles: :company_admin)
    raw = connection_for(SingleRoleUser).select_value("select roles from single_role_users limit 1")
    assert_equal "company_admin", raw
  end

  def test_single_round_trips_through_the_database
    SingleRoleUser.create!(email: "a@example.com", roles: :company_admin)
    assert_equal [:company_admin, :user], SingleRoleUser.first.reload.roles
  end

  ##############################################################################
  # role / role= singular aliases
  ##############################################################################

  def test_role_returns_the_first_role
    assert_equal :root_admin, MultiRoleUser.new(roles: [:root_admin]).role
    assert_equal :company_admin, SingleRoleUser.new(roles: :company_admin).role
  end

  def test_role_assignment_is_an_alias_for_roles_assignment
    user = MultiRoleUser.new
    user.role = :company_admin
    assert_equal [:company_admin, :user], user.roles
  end

  ##############################################################################
  # has_roles?
  ##############################################################################

  def test_has_roles_is_true_for_a_role_the_user_holds
    assert MultiRoleUser.new(roles: [:company_admin]).has_roles?(:company_admin)
  end

  def test_has_roles_is_false_for_a_role_the_user_lacks
    refute MultiRoleUser.new(roles: [:company_admin]).has_roles?(:root_admin)
  end

  def test_has_roles_is_true_when_any_of_the_given_roles_match
    assert MultiRoleUser.new(roles: [:company_admin]).has_roles?(:root_admin, :company_admin)
  end

  def test_has_roles_is_false_with_no_arguments
    refute MultiRoleUser.new(roles: [:company_admin]).has_roles?
  end

  def test_has_role_is_an_alias_for_has_roles
    assert MultiRoleUser.new(roles: [:company_admin]).has_role?(:company_admin)
  end

  def test_every_user_implicitly_has_the_user_role
    assert MultiRoleUser.new.has_role?(:user)
  end

  ##############################################################################
  # Generated scopes
  ##############################################################################

  def test_multiple_defines_a_pluralized_scope_per_role
    assert_respond_to MultiRoleUser, :role_root_admins
    assert_respond_to MultiRoleUser, :role_company_admins
  end

  def test_multiple_scope_finds_users_holding_that_role
    admin = MultiRoleUser.create!(email: "admin@example.com", roles: [:root_admin])
    MultiRoleUser.create!(email: "plain@example.com")

    assert_equal [admin.id], MultiRoleUser.role_root_admins.pluck(:id)
    assert_empty MultiRoleUser.role_company_admins
  end

  def test_multiple_scope_finds_a_user_holding_several_roles
    user = MultiRoleUser.create!(email: "both@example.com", roles: [:root_admin, :company_admin])

    assert_equal [user.id], MultiRoleUser.role_root_admins.pluck(:id)
    assert_equal [user.id], MultiRoleUser.role_company_admins.pluck(:id)
  end

  def test_single_scope_finds_users_holding_that_role
    admin = SingleRoleUser.create!(email: "admin@example.com", roles: :root_admin)
    SingleRoleUser.create!(email: "plain@example.com")

    assert_equal [admin.id], SingleRoleUser.role_root_admins.pluck(:id)
    assert_empty SingleRoleUser.role_company_admins
  end
  ##############################################################################
  # Reconfiguring and subclassing
  ##############################################################################

  def test_configuring_a_model_twice_keeps_the_first_set_of_roles
    assert_equal [:first_role, :user], TwiceConfigured::ROLES
  end

  def test_a_role_from_the_discarded_second_call_is_not_assignable
    assert_equal [:user], TwiceConfigured.new(roles: :second_role).roles
  end

  def test_a_subclass_inherits_its_parents_roles
    assert_equal MultiRoleUser::ROLES, InheritedRoles::ROLES
    assert_equal MultiRoleUser::ROLES, InheritedRoles.new.available_roles
  end

  def test_a_role_constant_from_an_included_module_is_not_mistaken_for_configuration
    # Only the superclass chain decides whether a model is already configured.
    # A concern carrying its own ROLES belongs to somebody else, and must not
    # stop this model from getting its own.
    foreign = Module.new do
      def self.name; "ForeignRoles"; end
      const_set(:ROLES, [:not_ours])
    end

    model = Class.new(ActiveRecord::Base) do
      def self.name; "ModelWithConcern"; end
      self.table_name = "accounts"
      include foreign
      petergate(roles: [:supervisor], multiple: false)
    end

    assert_equal [:supervisor, :user], model::ROLES
    assert_equal [:supervisor, :user], model.new.available_roles
    assert_equal [:supervisor, :user], model.new(roles: :supervisor).roles
  end

  ##############################################################################
  # Unexpected stored values
  ##############################################################################

  def test_a_stored_value_of_an_unexpected_type_reads_as_user
    user = MultiRoleUser.new
    user[:roles] = 42
    assert_equal [:user], user.roles
  end

  ##############################################################################
  # Roles the record's class does not define
  ##############################################################################

  def test_a_role_the_class_does_not_define_is_ignored
    # An STI type change is how this happens in practice: the row keeps the
    # roles of the kind it used to be. Written straight to the column, because
    # roles= is exactly what normally prevents it.
    #
    # :root_admin is the case that matters -- it bypasses every rule.
    employee = Employee.create!(email: "e@example.com", roles: [:root_admin])
    assert_includes employee.roles, :root_admin

    connection_for(Staff).update("update staff set type = 'Manager' where id = #{employee.id}")
    manager = Manager.find(employee.id)

    refute_includes Manager::ROLES, :root_admin
    refute_includes manager.roles, :root_admin
    refute manager.has_roles?(:root_admin), "a role the class does not define must not authorize"
    assert_equal [:user], manager.roles
  end

  def test_roles_the_class_does_define_survive_the_filtering
    employee = Employee.create!(email: "e2@example.com", roles: [:root_admin, :viewer])
    connection_for(Staff).update("update staff set type = 'Manager' where id = #{employee.id}")

    manager = Manager.find(employee.id)

    # Manager defines :viewer but not :root_admin.
    assert_includes manager.roles, :viewer
    refute_includes manager.roles, :root_admin
    assert manager.has_roles?(:viewer)
  end

  def test_a_subclass_without_its_own_petergate_call_uses_its_parents_roles
    assert_equal MultiRoleUser::ROLES, InheritedRoles::ROLES

    inherited = InheritedRoles.create!(email: "i@example.com", roles: [:company_admin])
    assert_includes inherited.roles, :company_admin
  end

  def test_a_multi_role_column_holding_strings_is_rejected_not_normalized
    # `roles=` has always written symbols here, so an array of strings can only
    # have come from a raw write. It matched nothing before 3.2, and it must not
    # start granting now -- this release can only take access away.
    user = MultiRoleUser.create!(email: "str@example.com")
    user[:roles] = ["company_admin"]
    user.save!

    reloaded = MultiRoleUser.find(user.id)
    refute reloaded.has_roles?(:company_admin)
    assert_equal [:user], reloaded.roles
  end

  def test_the_warning_explains_a_string_rather_than_contradicting_itself
    # Saying the class "does not define" :company_admin while its ROLES clearly
    # lists it sends the reader to look at their petergate call, where nothing
    # is wrong. The format is the problem, and the warning has to say so.
    # A role/class pair no other test touches: the warning fires once per pair
    # for the life of the process, so sharing one makes the assertion depend on
    # test order.
    user = MultiRoleUser.create!(email: "warn@example.com")
    user[:roles] = ["root_admin"]
    user.save!

    _out, err = capture_io { MultiRoleUser.find(user.id).roles }

    assert_match(/holds it as a string/, err)
    assert_match(/other than `roles=`/, err)
    refute_match(/does not declare it/, err)
  end

  def test_a_single_role_column_holding_a_string_still_works
    # The single-role setter has always accepted a string from a form, and the
    # reader has always symbolized it.
    user = SingleRoleUser.create!(email: "one@example.com", role: "company_admin")
    assert_equal [:company_admin, :user], SingleRoleUser.find(user.id).roles
  end
end
