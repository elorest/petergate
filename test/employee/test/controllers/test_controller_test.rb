require "test_helper"

class TestController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    forbidden! params[:msg]
  end
end

describe TestController, '#forbidden!' do
  let(:admin) { employees(:admin) }

  before do
    Employee.petergate(roles: [:root_admin, :company_admin], multiple: true)
    create_user_and_login
  end
  
  describe 'with html format request' do
    it 'redirect to referrer' do
      get edit_blog_path(Blog.first), headers: {'Referrer': 'http://referrer-page.com'}
      assert_redirected_to 'http://referrer-page.com'
    end

    it 'redirect to after_sign_in_path_for' do
      get new_employee_session_path
      assert_redirected_to root_path
    end

    it 'redirect to sign_in if not signed in' do
      sign_out admin
      get blog_path(Blog.first)
      assert_redirected_to new_employee_session_path
    end

    it 'uses the msg when supplied' do
      get edit_blog_path(Blog.first), headers: { msg: 'custom message' }
      assert_equal('custom message', flash[:notice])
    end
  end

  describe 'with xhr format request' do
    it 'respond with forbidden status' do
      get edit_blog_path(Blog.first), headers: { 'Accept': Mime[:js].to_s, 'Content-Type': Mime[:js].to_s }
      assert_response :forbidden
    end
  end
end
