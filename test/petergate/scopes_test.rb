require "test_helper"

# Authorizing against something other than `current_user`.
#
# Two architectures need this, and they get the same declaration:
#
#   petergate_scope Employee   # STI: one login, narrowed by type
#   petergate_scope Vendor     # a separately authenticated model
#
# Which one is in play is read off Devise's mappings at request time rather
# than configured, so these tests cover both through one API.
class ScopesTest < Petergate::RequestTest
  def customer;  @customer  ||= Staff.create!(email: "c@example.com",  roles: [:viewer]) end
  def employee;  @employee  ||= Employee.create!(email: "e@example.com", roles: [:viewer]) end
  def manager;   @manager   ||= Manager.create!(email: "m@example.com",  roles: [:viewer]) end
  def supporter; @supporter ||= Employee.create!(email: "s@example.com", roles: [:support]) end
  def vendor;    @vendor    ||= Vendor.create!(email: "v@example.com",   roles: [:supplier]) end

  ##############################################################################
  # A scope separates kinds that share a role name
  ##############################################################################

  def test_a_shared_role_name_is_separated_by_the_scope
    # Both hold :viewer, and both are in the same table behind the same login.
    assert_includes customer.roles, :viewer
    assert_includes employee.roles, :viewer

    as(employee, scope: :staff) do
      get "/employee_only"
      assert_response :success
    end

    as(customer, scope: :staff) do
      get "/employee_only"
      assert_response :redirect
    end
  end

  def test_the_scope_is_inherited_by_subclasses_of_the_controller
    # The child never names a scope; it takes `petergate_scope Employee` from
    # its parent, so :viewer here still means an Employee's :viewer.
    as(employee, scope: :staff) do
      get "/employee_child/s"
      assert_response :success
      assert_equal "show", response.body
    end

    as(customer, scope: :staff) do
      get "/employee_child/s"
      assert_response :redirect
    end
  end

  def test_a_child_declaring_the_same_scope_replaces_the_parents_rules
    # The child narrows :viewer to [:index, :show]; :support keeps :all only on
    # the parent, so the child must refuse a supporter's destroy.
    as(supporter, scope: :staff) do
      delete "/employee_child/1"
      assert_response :redirect
    end
  end

  ##############################################################################
  # Exact type matching
  ##############################################################################

  def test_a_class_scope_matches_that_class_exactly
    as(employee, scope: :staff) do
      get "/exact_match"
      assert_response :success
    end
  end

  def test_a_subclass_does_not_satisfy_its_parents_scope
    # Manager < Employee, but `as: Employee` means an Employee.
    as(manager, scope: :staff) do
      get "/exact_match"
      assert_response :redirect
    end
  end

  def test_a_subclass_satisfies_a_scope_naming_it
    as(manager, scope: :staff) do
      get "/exact_match/s"
      assert_response :success
    end
  end

  def test_declaring_two_classes_that_share_a_devise_scope_keeps_both
    # Employee and Manager resolve to the same Devise scope. Keyed on that
    # rather than on what was declared, the second `access` would have replaced
    # the first instead of widening access.
    assert_equal [Employee, Manager], ExactMatchController.petergate_rules.keys,
                 "a rule per declared class, not one overwriting the other"
  end

  ##############################################################################
  # A subclass replaces what it inherited
  ##############################################################################

  def test_a_child_naming_a_different_scope_drops_the_parents_rules
    # WideParent grants :company_admin everything on the :user scope.
    # NarrowChild is about Employee. Merging the two would leave the parent's
    # grant live, and any signed-in :company_admin would reach every action
    # under the child -- an upgrade quietly widening access.
    admin = MultiRoleUser.create!(email: "w@example.com", roles: [:company_admin])

    as(admin) do
      delete "/narrow_child/1"
      assert_response :redirect
    end
  end

  def test_a_child_still_grants_its_own_scope
    supporter = Employee.create!(email: "sup@example.com", roles: [:support])
    as(supporter, scope: :staff) do
      delete "/narrow_child/1"
      assert_response :success
    end
  end

  def test_petergate_scope_after_access_still_governs_the_rule
    # Declared in the other order, the rule would authorize the wrong model.
    supporter = Employee.create!(email: "late@example.com", roles: [:support])
    as(supporter, scope: :staff) do
      get "/late_scope"
      assert_response :success
    end
  end

  def test_a_missing_authenticator_is_reported_on_the_path_that_calls_it
    # current_droid exists, authenticate_droid! does not. The HTML denial path
    # is the only one that calls it, and there it still has to say so.
    error = assert_raises(Petergate::MissingScopeError) { get "/droid" }

    assert_match(/authenticate_droid!/, error.message)
  end

  def test_a_lenient_lookup_outside_a_check_is_not_remembered
    # No access declaration, so petergate's own callback never runs and never
    # sets up its cache. A lenient peek from an app filter must not leave a nil
    # behind for the filter that signs someone in afterwards.
    MultiRoleUser.create!(email: "peek@example.com", roles: [:company_admin])

    get "/no_rules_peek"
    assert_equal "any=true", response.body
  end

  def test_a_lenient_lookup_does_not_suppress_a_later_missing_scope_error
    # The app's own filter asks about a bogus scope leniently first. Caching
    # that nil would make whether petergate raises depend on callback order.
    assert_raises(Petergate::MissingScopeError) { get "/lenient_first" }
  end

  def test_petergate_scope_governs_rules_declared_above_it
    # The rules live on the parent and named no scope, so they follow this
    # tree's petergate_scope. Otherwise a base controller declaring the scope
    # would be a no-op whenever the rules came from above it -- and a
    # :company_admin on the :user scope would walk straight through.
    admin = MultiRoleUser.create!(email: "tree@example.com", roles: [:company_admin])
    as(admin) do
      delete "/scoped_tree_staff/1"
      assert_response :redirect
    end

    employee_admin = Employee.create!(email: "ea@example.com", roles: [:company_admin])
    refute_includes Employee::ROLES, :company_admin
    as(employee_admin, scope: :staff) do
      delete "/scoped_tree_staff/1"
      assert_response :redirect
    end
  end

  def test_a_named_scope_survives_a_later_petergate_scope
    # The Vendor rule was asked for by name and must not be overwritten by the
    # defaulted one when petergate_scope is declared afterwards.
    as(vendor, scope: :vendor) do
      get "/two_scope_kinds"
      assert_response :success
    end
  end

  def test_the_defaulted_rule_follows_the_declared_scope
    supporter = Employee.create!(email: "tsk@example.com", roles: [:support])
    as(supporter, scope: :staff) do
      get "/two_scope_kinds/s"
      assert_response :success
    end
  end

  def test_an_explicitly_named_user_scope_is_not_re_filed
    admin = MultiRoleUser.create!(email: "eu@example.com", roles: [:company_admin])
    as(admin) do
      get "/explicit_user_scope"
      assert_response :success
    end
  end

  def test_a_class_that_is_not_a_model_is_refused_at_declaration
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TestAuthentication
        access Struct.new(:x), admin: :all
      end
    end

    assert_match(/cannot be a petergate scope/, error.message)
    assert_match(/not a model/, error.message)
  end

  def test_a_resource_signed_in_after_a_lenient_lookup_is_still_seen
    # A nil must not be cached: an app filter can sign someone in after
    # petergate has already looked.
    MultiRoleUser.create!(email: "late@example.com", roles: [:company_admin])
    get "/late_sign_in"
    assert_response :success
  end

  ##############################################################################
  # The callback is installed where rules are declared
  ##############################################################################

  def test_a_subclass_declaring_rules_after_a_skip_still_enforces_them
    # An ancestor ran skip_before_action; this class then declared its own
    # rules. If installation is guarded by an inherited flag, nothing enforces
    # them and every action is reachable by anyone.
    assert_includes SkipChildController._process_action_callbacks.map(&:filter),
                    :petergate_check_access!

    get "/skip_child"
    assert_response :redirect

    admin = MultiRoleUser.create!(email: "sk@example.com", roles: [:company_admin])
    as(admin) do
      delete "/skip_child/1"
      assert_response :success
    end
  end

  def test_a_skip_without_new_rules_is_still_honoured
    refute_includes SkipMiddleController._process_action_callbacks.map(&:filter),
                    :petergate_check_access!
  end

  def test_declaring_access_twice_registers_one_callback
    filters = DualScopeController._process_action_callbacks.map(&:filter)
    assert_equal 1, filters.count(:petergate_check_access!)
  end

  def test_the_callback_lands_after_a_filter_the_subclass_declared_first
    # The subclass's own filter populates the resource, so petergate has to run
    # after it. Inheriting the ancestor's callback position means looking
    # before anyone is there.
    chain = TokenChildController._process_action_callbacks.map(&:filter)
    assert_operator chain.index(:authenticate_from_token), :<,
                    chain.index(:petergate_check_access!)

    MultiRoleUser.create!(email: "token@example.com", roles: [:company_admin])
    delete "/token_child/1"
    assert_response :success
  end

  def test_a_resource_signed_in_during_the_action_is_visible_to_the_view
    # The check's resource cache must not outlive the check: an action that
    # signs someone in and then renders would draw its layout for a stranger.
    MultiRoleUser.create!(email: "mid@example.com", roles: [:company_admin])
    get "/mid_action_sign_in"

    assert_equal "any=true admin=true", response.body
  end

  def test_a_falsy_positional_argument_is_refused
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TestAuthentication
        access false, user: [:index]
      end
    end

    assert_match(/scope/, error.message)
  end

  ##############################################################################
  # A mistyped scope is reported whoever is signed in
  ##############################################################################

  def test_a_missing_scope_is_reported_even_when_an_earlier_rule_is_satisfied
    # The passes short-circuit, so without resolving every declared scope up
    # front this would raise for a visitor and stay silent for a root_admin.
    assert_raises(Petergate::MissingScopeError) { get "/typo_after_grant" }

    as(vendor, scope: :vendor) do
      assert_raises(Petergate::MissingScopeError) { get "/typo_after_grant" }
    end

    root = Vendor.create!(email: "vra@example.com", roles: [:root_admin])
    as(root, scope: :vendor) do
      assert_raises(Petergate::MissingScopeError) { get "/typo_after_grant" }
    end
  end

  def test_petergate_scope_refuses_a_class_that_is_not_a_model
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TestAuthentication
        petergate_scope Struct.new(:x)
      end
    end

    assert_match(/cannot be a petergate scope/, error.message)
  end

  def test_petergate_scope_refuses_a_string
    # To `access` a string is the denial message, so accepting one here would
    # make the same literal mean two different things depending on which
    # declaration it landed in.
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TestAuthentication
        petergate_scope "staff"
      end
    end

    assert_match(/not the string "staff"/, error.message)
    assert_match(/petergate_scope :staff/, error.message)
  end

  def test_a_string_is_still_the_denial_message_to_access
    # The other half of the pair: the same literal, still a message.
    controller = Class.new(ActionController::Base) do
      include TestAuthentication
      access "Staff only", admin: :all
    end

    assert_equal "Staff only", controller.controller_message
  end

  def test_each_login_is_looked_up_once_per_request
    # Several rules, and one of them grants early. Every declared scope still
    # has to be checked for existence, but no login should be read twice, and
    # an empty one should not be re-read for each pass.
    calls = Hash.new(0)
    counter = Module.new do
      define_method(:current_staff)  { calls[:staff]  += 1; super() }
      define_method(:current_vendor) { calls[:vendor] += 1; super() }
      private :current_staff, :current_vendor
    end
    DualScopeController.prepend(counter)

    as(employee, scope: :staff) do
      get "/dual_scope"
      assert_response :success
    end

    assert_equal 1, calls[:staff],  "the signed-in login was read more than once"
    assert_equal 1, calls[:vendor], "an empty login was read more than once"
  end

  ##############################################################################
  # OR across scopes
  ##############################################################################

  def test_each_scope_is_satisfied_independently
    as(employee, scope: :staff) { get    "/dual_scope";   assert_response :success }
    as(customer, scope: :staff) { get    "/dual_scope/s"; assert_response :success }
    as(vendor,   scope: :vendor) { delete "/dual_scope/1"; assert_response :success }
  end

  def test_a_scope_grants_only_its_own_actions
    as(employee, scope: :staff) do
      get "/dual_scope/s"
      assert_response :redirect
    end
  end

  def test_two_scopes_can_be_signed_in_at_once
    as(customer, scope: :staff) do
      as(vendor, scope: :vendor) do
        delete "/dual_scope/1"
        assert_response :success

        get "/dual_scope/s"
        assert_response :success
      end
    end
  end

  ##############################################################################
  # root_admin
  ##############################################################################

  def test_root_admin_bypasses_within_a_declared_scope
    admin = Employee.create!(email: "ra@example.com", roles: [:root_admin])
    as(admin, scope: :staff) do
      delete "/employee_only/1"
      assert_response :success
    end
  end

  def test_root_admin_in_an_undeclared_scope_does_not_bypass
    # VendorOnlyController declares only the Vendor scope. A root_admin signed
    # in to another scope must not be let through it.
    admin = Employee.create!(email: "ra2@example.com", roles: [:root_admin])
    as(admin, scope: :staff) do
      get "/vendor_only"
      assert_response :redirect
      assert_redirected_to "/vendor_sign_in"
    end
  end

  def test_root_admin_has_to_be_declared_before_it_can_bypass
    # Staff does not list :root_admin, so a Staff cannot hold it and there is
    # no bypass to perform. The magic name alone is not enough.
    refute_includes Staff::ROLES, :root_admin

    pretender = Staff.create!(email: "p@example.com", roles: [:root_admin])
    assert_equal [:user], pretender.roles

    as(pretender, scope: :staff) do
      get "/dual_scope"
      assert_response :redirect
    end
  end

  ##############################################################################
  # Which denial, and which login
  ##############################################################################

  def test_a_visitor_is_sent_to_the_declared_scopes_login
    get "/vendor_only"
    assert_redirected_to "/vendor_sign_in"
  end

  def test_a_signed_in_person_of_the_wrong_type_is_forbidden_not_bounced
    # One login: the scope is occupied, so there is nothing further to
    # authenticate as and sending them to a sign-in form would loop.
    as(customer, scope: :staff) do
      get "/employee_only"
      assert_redirected_to "/dashboard"
      assert_equal "Permission Denied", flash[:notice]
    end
  end

  def test_a_person_signed_in_to_another_scope_is_sent_to_this_ones_login
    # The :vendor scope is genuinely empty, so a login is the right answer even
    # though this person is already signed in elsewhere.
    as(customer, scope: :staff) do
      get "/vendor_only"
      assert_redirected_to "/vendor_sign_in"
    end
  end

  def test_petergate_scope_picks_the_login_when_several_are_declared
    get "/vendor_primary"
    assert_redirected_to "/vendor_sign_in"
  end

  def test_a_missing_symbol_scope_helper_is_reported
    error = assert_raises(Petergate::MissingScopeError) { get "/missing_scope" }

    assert_match(/current_nobody/, error.message)
    assert_match(/MissingScopeController/, error.message)
    assert_match(/devise_for :nobodies/, error.message)
  end

  def test_a_class_that_resolves_to_its_own_name_asks_for_its_own_login
    # Blog resolves to :blog, its own name -- so the fix is a devise_for of its
    # own, or a hand-written helper. Not a parent's problem.
    error = assert_raises(Petergate::MissingScopeError) { get "/non_auth_scope" }

    assert_match(/current_blog/, error.message)
    assert_match(/devise_for :blogs/, error.message)
    refute_match(/shares a login/, error.message)
  end

  def test_a_class_that_resolves_to_an_ancestors_scope_says_so
    # GhostChild resolves to :ghost, its parent's scope -- the fix belongs on
    # the parent, and the message has to say so rather than pointing here.
    error = assert_raises(Petergate::MissingScopeError) { get "/inherited_scope" }

    assert_match(/current_ghost/, error.message)
    assert_match(/shares a login with a parent class/, error.message)
  end

  def test_webservice_requests_still_get_bare_statuses
    webservice_formats.each do |format|
      get "/vendor_only", headers: headers_for(format), xhr: true
      assert_response :unauthorized, "expected 401 for #{format}"
    end

    as(customer, scope: :staff) do
      webservice_formats.each do |format|
        get "/employee_only", headers: headers_for(format), xhr: true
        assert_response :forbidden, "expected 403 for #{format}"
      end
    end
  end

  ##############################################################################
  # Messages
  ##############################################################################

  def test_the_message_comes_from_the_scope_that_refused_a_signed_in_person
    as(employee, scope: :staff)  { delete "/scoped_message/1"; assert_equal "staff only",   flash[:notice] }
    as(vendor,   scope: :vendor) { delete "/scoped_message/1"; assert_equal "vendors only", flash[:notice] }
  end

  ##############################################################################
  # View helpers
  ##############################################################################

  def test_helpers_resolve_against_the_controllers_scope_and_an_explicit_one
    as(supporter, scope: :staff) do
      as(vendor, scope: :vendor) do
        get "/scoped_helpers"
        assert_equal "default=true vendor=true typo= any=true", response.body
      end
    end
  end

  def test_an_unknown_scope_renders_false_rather_than_raising_in_a_view
    get "/scoped_helpers"
    assert_response :success
    assert_equal "default= vendor= typo= any=false", response.body
  end
end
