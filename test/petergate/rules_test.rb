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
end
