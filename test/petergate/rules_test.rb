require "test_helper"

# How `access` rule values are interpreted.
class RulesTest < Petergate::RequestTest
  def plain_user
    @plain_user ||= MultiRoleUser.create!(email: "plain@example.com")
  end

  ##############################################################################
  # Expanding action lists
  ##############################################################################

  def test_all_actions_lists_every_action_on_the_controller
    assert_equal %i[index show new edit create update destroy].sort,
                 BlogsController.all_actions.sort
  end

  def test_all_actions_excludes_the_controllers_authentication_helpers
    # current_user and friends are private, so they must not look like actions.
    refute_includes BlogsController.all_actions, :current_user
    refute_includes BlogsController.all_actions, :authenticate_user!
  end

  def test_all_actions_excludes_public_helpers_inherited_from_a_concrete_superclass
    # Rails' action_methods reports all of these, because internal_methods only
    # subtracts up to the first abstract controller. petergate has to reject
    # them itself or `:all` grants them as if they were actions.
    actions = PublicHelperController.all_actions

    refute_includes actions, :current_employee,       "a helper_method is not an action"
    refute_includes actions, :authenticate_employee!, "a bang method is not an action"
    refute_includes actions, :employee_signed_in?,    "a predicate is not an action"
    refute_includes actions, :after_sign_in_path_for, "a method taking an argument is not an action"
  end

  def test_a_method_that_cannot_be_an_action_is_excluded_even_when_declared_here
    # Declaring a method on the controller says it is an action, but that
    # cannot override taking an argument -- Rails dispatches with none.
    assert_equal [:index], OwnArgumentController.all_actions
  end

  def test_all_actions_keeps_an_action_the_controller_declares_itself
    # user_session collides with a Devise helper name, but this controller
    # defines it, so it is an action and filtering must not eat it.
    assert_equal %i[index user_session].sort, PublicHelperController.all_actions.sort
  end

  def test_all_actions_picks_up_a_method_defined_after_it_was_first_read
    # The result is memoized against the identity of Rails' action_methods Set,
    # which Rails replaces whenever a method is added -- so a controller that
    # gains an action later must not keep serving a stale list.
    controller = Class.new(ActionController::Base) do
      include TestAuthentication
      def index; end
    end

    assert_equal [:index], controller.all_actions

    controller.class_eval { def show; end }

    assert_equal %i[index show].sort, controller.all_actions.sort
  end

  def test_all_actions_never_publishes_its_guard_before_its_value
    # A thread arriving while another is still computing must not take the
    # early return and get nil: that reaches parse_permission_rules, where
    # `:all` expands to nothing and `except:` raises on nil.
    controller = Class.new(ActionController::Base) do
      include TestAuthentication
      def index; end
      def show;  end
    end
    controller.singleton_class.prepend(Module.new do
      def petergate_action_names(methods)
        sleep 0.15
        super
      end
    end)

    results = Queue.new
    first   = Thread.new { results << controller.all_actions }
    sleep 0.05
    second  = Thread.new { results << controller.all_actions }
    [first, second].each(&:join)

    two = [results.pop, results.pop]
    two.each { |actions| assert_equal %i[index show].sort, actions.to_a.sort }
  end

  def test_all_actions_is_memoized_between_reads
    first = BlogsController.all_actions
    assert_same first, BlogsController.all_actions
  end

  def test_except_actions_removes_the_named_actions
    assert_equal %i[index show new edit create update].sort,
                 BlogsController.except_actions([:destroy]).sort
  end

  ##############################################################################
  # Rule shapes
  ##############################################################################

  def test_the_all_symbol_grants_every_action
    get "/open"
    assert_response :success

    delete "/open/1"
    assert_response :success
  end

  def test_an_array_of_role_keys_shares_one_action_list
    get "/shared_keys"
    assert_response :success

    delete "/shared_keys/1"
    assert_response :redirect

    as plain_user do
      get "/shared_keys"
      assert_response :success
    end
  end

  def test_rules_may_be_supplied_by_a_block
    get "/block_rules"
    assert_response :success

    delete "/block_rules/1"
    assert_response :redirect
  end

  ##############################################################################
  # Malformed rules
  ##############################################################################

  def test_a_symbol_other_than_all_is_rejected
    error = assert_raises(RuntimeError) { get "/bad_symbol" }
    assert_equal "No action for: bogus", error.message
  end

  def test_a_hash_without_except_is_rejected
    error = assert_raises(RuntimeError) { get "/bad_except" }
    assert_match(/Invalid values for except/, error.message)
  end

  def test_a_value_that_is_neither_symbol_hash_nor_array_is_rejected
    error = assert_raises(RuntimeError) { get "/bad_value" }
    assert_equal "No action for: 42", error.message
  end

  ##############################################################################
  # Deprecated AllRest / ALLREST constants
  ##############################################################################

  def test_allrest_still_resolves_to_the_rest_actions
    _out, err = capture_io { @actions = ActionController::Base::ALLREST }
    assert_equal %i[show index new edit update create destroy], @actions
    assert_match(/deprecated/, err)
  end

  def test_the_camel_case_spelling_also_resolves
    _out, err = capture_io { @actions = ActionController::Base::AllRest }
    assert_equal %i[show index new edit update create destroy], @actions
    assert_match(/deprecated/, err)
  end

  def test_it_resolves_from_a_subclass_too
    _out, _err = capture_io { @actions = BlogsController::ALLREST }
    assert_kind_of Array, @actions
  end

  def test_an_unrelated_missing_constant_still_raises
    assert_raises(NameError) { ActionController::Base::NoSuchConstant }
  end

  ##############################################################################
  # View helpers
  ##############################################################################

  def test_petergate_predicates_are_available_to_views
    as MultiRoleUser.create!(email: "company@example.com", roles: [:company_admin]) do
      get "/helpers"
      assert_equal "admin=true root=false", response.body
    end
  end

  def test_view_helpers_report_a_signed_out_visitor
    get "/helpers"
    assert_equal "admin= root=", response.body
  end
  ##############################################################################
  # Edge cases in rule declaration and denial
  ##############################################################################

  def test_a_block_returning_something_other_than_a_hash_is_ignored
    get "/block_returning_nil"
    assert_response :success

    delete "/block_returning_nil/1"
    assert_response :redirect
  end

  def test_forbidden_falls_back_to_the_default_message_with_no_declared_rules
    # A controller can call forbidden! from its own before_action without ever
    # declaring `access`, so there is no controller_message to read.
    as plain_user do
      get "/no_rules_forbid"
      assert_equal "Permission Denied", flash[:notice]
    end
  end

  def test_an_at_user_stands_in_for_current_user_when_choosing_the_denial
    # With @user set but nobody signed in, a refusal is a forbidden rather than
    # a request to authenticate -- so it redirects to root, not to sign in.
    delete "/ghost_user/1"
    assert_redirected_to "/"
    refute_equal "/sign_in", response.headers["Location"]
  end
end
