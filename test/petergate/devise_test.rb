require "test_helper"

# petergate does not depend on Devise -- it depends on the three methods the
# README asks a host application for:
#
#     current_user
#     after_sign_in_path_for(current_user)
#     authenticate_user!
#
# The rest of the suite supplies those directly, which tests petergate rather
# than Devise. This file closes the other half: that Devise, the auth layer the
# README recommends, really does satisfy the contract petergate expects.
class DeviseTest < Petergate::RequestTest
  if DEVISE_AVAILABLE
    include Devise::Test::IntegrationHelpers

    def company_admin
      @company_admin ||= User.create!(
        email: "company@example.com", password: "correct horse battery",
        roles: [:company_admin]
      )
    end

    def plain_user
      @plain_user ||= User.create!(email: "plain@example.com", password: "correct horse battery")
    end

    def test_devise_supplies_the_methods_petergate_calls
      controller = DeviseBackedController.new
      %i[current_user authenticate_user! after_sign_in_path_for].each do |method|
        assert_respond_to controller, method,
                          "Devise no longer provides #{method}, which petergate calls"
      end
    end

    def test_devise_roles_are_stored_and_read_back
      assert_equal [:company_admin, :user], company_admin.reload.roles
    end

    def test_an_action_granted_to_all_is_reachable_without_signing_in
      get "/devise_backed"
      assert_response :success
    end

    def test_a_signed_in_user_with_the_role_is_allowed
      sign_in company_admin
      delete "/devise_backed/1"
      assert_response :success
      assert_equal "destroy", response.body
    end

    def test_a_signed_in_user_without_the_role_is_refused
      sign_in plain_user
      delete "/devise_backed/1"
      assert_response :redirect
      assert_equal "Permission Denied", flash[:notice]
    end

    def test_a_refused_user_lands_on_devises_own_signed_in_destination
      # petergate hands off to after_sign_in_path_for; Devise resolves that to
      # the signed-in root, so the redirect has to be a real path rather than
      # nil or an error.
      sign_in plain_user
      delete "/devise_backed/1"
      assert_redirected_to "/"
    end

    def test_a_visitor_is_handed_to_devises_authenticate_user
      # petergate calls authenticate_user!, and Devise turns that into its own
      # sign-in redirect through Warden.
      delete "/devise_backed/1"
      assert_redirected_to new_user_session_path
    end

    ############################################################################
    # Scopes, resolved through Devise's real mappings
    ############################################################################

    def approver
      @approver ||= Approver.create!(email: "approver@example.com",
                                     password: "correct horse battery", roles: [:approver])
    end

    def supplier
      @supplier ||= Supplier.create!(email: "supplier@example.com",
                                     password: "correct horse battery", roles: [:shipping])
    end

    def test_devise_mappings_resolve_the_scopes_petergate_declares
      # An STI subclass has no mapping of its own, so it shares the parent's
      # login; a separately mapped model gets its own.
      assert_equal :user,     Petergate.devise_scope_for(Approver)
      assert_equal :supplier, Petergate.devise_scope_for(Supplier)
      assert_includes Devise.mappings.keys, :supplier
    end

    def test_an_sti_subclass_is_authorized_through_the_shared_login
      sign_in approver
      delete "/devise_sti/1"
      assert_response :success
    end

    def test_the_parent_class_does_not_satisfy_a_subclass_rule
      # Same login, same session, wrong type -- and nothing else to
      # authenticate as, so this is a refusal rather than a trip to sign-in.
      sign_in company_admin
      delete "/devise_sti/1"
      assert_response :redirect
      refute_equal new_user_session_path, response.headers["Location"]
    end

    def test_a_separately_mapped_model_is_authorized_through_its_own_login
      sign_in supplier
      delete "/devise_supplier/1"
      assert_response :success
    end

    def test_a_user_reaching_a_supplier_page_is_sent_to_the_supplier_login
      # The :supplier scope really is empty, so a login is the right answer
      # even though this person is signed in as a User.
      sign_in company_admin
      delete "/devise_supplier/1"
      assert_redirected_to new_supplier_session_path
    end

    # One request per test, deliberately. Warden's test mode puts the record
    # itself in the session, and this app uses the `:json` cookie serializer
    # (as a generated Rails app does), so a second request in the same session
    # reads it back as a Hash of attributes rather than a record. That is an
    # artifact of signing in through the test helper, not of petergate -- but it
    # makes multi-request Devise tests here unreliable.
    def test_both_scopes_can_hold_a_session_at_once_for_the_first_scope
      sign_in approver
      sign_in supplier

      get "/devise_both_scopes"
      assert_response :success
    end

    def test_both_scopes_can_hold_a_session_at_once_for_the_second_scope
      sign_in approver
      sign_in supplier

      delete "/devise_both_scopes/1"
      assert_response :success
    end

    def test_a_visitor_is_sent_to_the_first_declared_scopes_login
      delete "/devise_both_scopes/1"
      assert_redirected_to new_user_session_path
    end

    def test_a_visitor_gets_401_for_a_webservice_request
      webservice_formats.each do |format|
        delete "/devise_backed/1", headers: headers_for(format), xhr: true
        assert_response :unauthorized, "expected 401 for #{format}"
      end
    end
  else
    def test_devise_integration_skipped
      skip "devise is not installed"
    end
  end
end
