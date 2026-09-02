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
