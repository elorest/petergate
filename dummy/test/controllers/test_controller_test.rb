require "test_helper"

class TestController < ApplicationController
  skip_before_filter :verify_authenticity_token
  access all: :all

  def index
    forbidden! params[:msg]
  end
end

describe "TestController", '#forbidden!' do
  let(:admin) { users(:admin) }
  before { sign_in admin }
  
  describe 'with html format request' do
    it 'redirect to referrer' do
      @request.env['HTTP_REFERER'] = 'http://referrer-page.com'
      get :index
      assert_redirected_to 'http://referrer-page.com'
    end

    it 'redirect to after_sign_in_path_for' do
      get :index
      assert_redirected_to root_path
    end

    it 'redirect to root_path if not signed in' do
      sign_out admin
      get :index
      assert_redirected_to root_url
    end

    it 'uses the msg when supplied' do
      get :index, msg: 'custom message'
      assert_equal('custom message', flash[:notice])
    end
  end

  describe 'with xhr format request' do
    it 'respond with forbidden status' do
      get :index, format: :js
      assert_response :forbidden
    end
  end
end
