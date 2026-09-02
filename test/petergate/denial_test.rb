require "test_helper"

# forbidden! and unauthorized! -- what petergate does once access is refused.
class DenialTest < Petergate::RequestTest
  def user
    @user ||= MultiRoleUser.create!(email: "plain@example.com")
  end

  ##############################################################################
  # forbidden!
  ##############################################################################

  def test_forbidden_sends_a_signed_in_user_back_where_they_came_from
    as user do
      get "/forbid", headers: { "Referer" => "http://www.example.com/blogs" }
      assert_redirected_to "http://www.example.com/blogs"
    end
  end

  def test_forbidden_refuses_to_bounce_a_user_to_another_host
    # The Referer is supplied by the caller, so an off-site value must not turn
    # a denial into an open redirect -- nor into a 500 from Rails' protection.
    as user do
      get "/forbid", headers: { "Referer" => "https://attacker.example/landing" }
      assert_redirected_to "/dashboard"
    end
  end

  def test_forbidden_falls_back_to_the_signed_in_destination_without_a_referer
    as user do
      get "/forbid"
      assert_redirected_to "/dashboard"
    end
  end

  def test_forbidden_sends_a_visitor_to_the_root_path
    get "/forbid"
    assert_redirected_to "/"
  end

  def test_forbidden_uses_the_default_message
    as user do
      get "/forbid"
      assert_equal "Permission Denied", flash[:notice]
    end
  end

  def test_forbidden_uses_an_explicitly_passed_message
    as user do
      get "/forbid", params: { msg: "no entry" }
      assert_equal "no entry", flash[:notice]
    end
  end

  def test_forbidden_uses_a_message_supplied_as_a_request_header
    as user do
      get "/forbid", headers: { "msg" => "header message" }
      assert_equal "header message", flash[:notice]
    end
  end

  def test_forbidden_answers_webservice_formats_with_403_and_no_body
    as user do
      webservice_formats.each do |format|
        get "/forbid", headers: headers_for(format), xhr: true
        assert_response :forbidden
        assert_predicate response.body, :empty?
      end
    end
  end

  ##############################################################################
  # unauthorized!
  ##############################################################################

  def test_unauthorized_hands_off_to_the_authentication_layer
    get "/deny"
    assert_redirected_to "/sign_in"
  end

  def test_unauthorized_answers_webservice_formats_with_401
    webservice_formats.each do |format|
      get "/deny", headers: headers_for(format), xhr: true
      assert_response :unauthorized
    end
  end

  ##############################################################################
  # The message: option on access
  ##############################################################################

  def test_the_message_option_replaces_the_default_denial_message
    as user do
      delete "/custom_message/1"
      assert_equal "You shall not pass", flash[:notice]
    end
  end

  def test_the_message_option_is_not_treated_as_a_role_rule
    as user do
      get "/custom_message"
      assert_response :success
    end
  end
end
