require "test_helper"

# The `access` DSL, exercised through real requests against BlogsController.
#
# The rules under test are declared on InheritanceController (see
# test/support/controllers.rb):
#
#   access all: [:index], user: [:index, :show], company_admin: { except: [:destroy] }
#
# BlogsController inherits them, which is itself part of what these tests cover.
module AccessMatrix
  extend ActiveSupport::Concern

  ##############################################################################
  # Signed-out visitors
  ##############################################################################

  def test_a_visitor_may_reach_an_action_granted_to_all
    get "/blogs"
    assert_response :success
    assert_equal "index", response.body
  end

  def test_a_visitor_is_sent_to_authentication_for_anything_else
    %w[/blogs/new /blogs/1 /blogs/1/edit].each do |path|
      get path
      assert_redirected_to "/sign_in", "expected #{path} to require authentication"
    end
  end

  def test_a_visitor_cannot_create
    assert_no_difference "Blog.count" do
      post "/blogs"
    end
    assert_redirected_to "/sign_in"
  end

  def test_a_visitor_cannot_destroy
    blog = Blog.create!(title: "t")
    assert_no_difference "Blog.count" do
      delete "/blogs/#{blog.id}"
    end
    assert_redirected_to "/sign_in"
  end

  def test_a_visitor_gets_401_rather_than_a_redirect_for_webservice_formats
    webservice_formats.each do |format|
      get "/blogs/new", headers: headers_for(format), xhr: true
      assert_response :unauthorized, "expected 401 for #{format}"
    end
  end

  ##############################################################################
  # Plain users
  ##############################################################################

  def test_a_plain_user_may_reach_the_actions_granted_to_the_user_role
    as plain_user do
      get "/blogs"
      assert_response :success

      get "/blogs/1"
      assert_response :success
    end
  end

  def test_a_plain_user_is_refused_anything_beyond_the_user_role
    as plain_user do
      %w[/blogs/new /blogs/1/edit].each do |path|
        get path
        assert_response :redirect, "expected #{path} to be refused"
        assert_equal "Permission Denied", flash[:notice]
      end
    end
  end

  def test_a_refused_user_is_redirected_to_the_signed_in_destination
    as plain_user do
      get "/blogs/new"
      assert_redirected_to "/dashboard"
    end
  end

  def test_a_plain_user_cannot_create
    as plain_user do
      assert_no_difference "Blog.count" do
        post "/blogs"
      end
      assert_response :redirect
    end
  end

  def test_a_plain_user_cannot_destroy
    blog = Blog.create!(title: "t")
    as plain_user do
      assert_no_difference "Blog.count" do
        delete "/blogs/#{blog.id}"
      end
      assert_response :redirect
    end
  end

  def test_a_plain_user_gets_403_rather_than_a_redirect_for_webservice_formats
    as plain_user do
      webservice_formats.each do |format|
        get "/blogs/new", headers: headers_for(format), xhr: true
        assert_response :forbidden, "expected 403 for #{format}"
      end
    end
  end

  ##############################################################################
  # A role with an `except:` rule
  ##############################################################################

  def test_a_company_admin_may_reach_every_action_but_the_excepted_one
    as company_admin do
      %w[/blogs /blogs/1 /blogs/new /blogs/1/edit].each do |path|
        get path
        assert_response :success, "expected #{path} to be allowed"
      end
    end
  end

  def test_a_company_admin_may_create
    as company_admin do
      assert_difference "Blog.count", 1 do
        post "/blogs"
      end
      assert_response :success
    end
  end

  def test_a_company_admin_may_not_destroy
    blog = Blog.create!(title: "t")
    as company_admin do
      assert_no_difference "Blog.count" do
        delete "/blogs/#{blog.id}"
      end
      assert_response :redirect
    end
  end

  ##############################################################################
  # root_admin bypass
  ##############################################################################

  def test_a_root_admin_bypasses_the_rules_entirely
    as root_admin do
      %w[/blogs /blogs/1 /blogs/new /blogs/1/edit].each do |path|
        get path
        assert_response :success, "expected #{path} to be allowed"
      end
    end
  end

  def test_a_root_admin_may_destroy_even_though_no_rule_grants_it
    blog = Blog.create!(title: "t")
    as root_admin do
      assert_difference "Blog.count", -1 do
        delete "/blogs/#{blog.id}"
      end
      assert_response :success
    end
  end
end

# The same matrix has to hold whichever way roles are stored.
class MultipleRolesAccessTest < Petergate::RequestTest
  include AccessMatrix

  def plain_user
    @plain_user ||= MultiRoleUser.create!(email: "plain@example.com")
  end

  def company_admin
    @company_admin ||= MultiRoleUser.create!(email: "company@example.com", roles: [:company_admin])
  end

  def root_admin
    @root_admin ||= MultiRoleUser.create!(email: "root@example.com", roles: [:root_admin])
  end
end

class SingleRoleAccessTest < Petergate::RequestTest
  include AccessMatrix

  def plain_user
    @plain_user ||= SingleRoleUser.create!(email: "plain@example.com")
  end

  def company_admin
    @company_admin ||= SingleRoleUser.create!(email: "company@example.com", roles: :company_admin)
  end

  def root_admin
    @root_admin ||= SingleRoleUser.create!(email: "root@example.com", roles: :root_admin)
  end
end
