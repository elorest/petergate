require "test_helper"

# ActionController::API has no MimeResponds and no helper_method, so petergate
# has to hook into it differently than it does ActionController::Base.
class ApiTest < Petergate::RequestTest
  def company_admin
    @company_admin ||= MultiRoleUser.create!(email: "company@example.com", roles: [:company_admin])
  end

  def plain_user
    @plain_user ||= MultiRoleUser.create!(email: "plain@example.com")
  end

  def test_api_controllers_get_the_access_dsl
    assert_respond_to ActionController::API, :access
  end

  def test_an_action_granted_to_all_is_reachable
    get "/widgets"
    assert_response :success
    assert_equal "index", response.parsed_body["action"]
  end

  def test_a_permitted_role_may_reach_a_restricted_action
    as company_admin do
      delete "/widgets/1"
      assert_response :success
      assert_equal "destroy", response.parsed_body["action"]
    end
  end

  def test_a_refused_user_gets_403_rather_than_a_redirect
    as plain_user do
      delete "/widgets/1"
      assert_response :forbidden
    end
  end

  def test_a_visitor_gets_401_rather_than_a_redirect
    delete "/widgets/1"
    assert_response :unauthorized
  end
end
