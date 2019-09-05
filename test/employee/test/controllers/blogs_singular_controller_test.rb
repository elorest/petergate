require "test_helper"

describe BlogsController do
  ################################################################################
  # ADMIN ROLE
  ################################################################################
  describe "Singular: Test that everything works if admin is logged in" do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: false)
      create_admin_and_login
    end

    let(:blog) { blogs :one }

    it "gets index" do
      get blogs_url
      assert_response :success
      assert_not_equal 0, Blog.count
    end

    it "gets new" do
      get new_blog_url
      assert_response :success
    end

    it "creates blog" do
      assert_difference('Blog.count') do
        post blogs_url, params: { blog: { content: blog.content, title: blog.title } }
      end

      assert_redirected_to blog_path(Blog.last)
    end

    it "shows blog" do
      get blog_url blog
      assert_response :success
    end

    it "gets edit" do
      get edit_blog_url blog
      assert_response :success
    end

    it "updates blog" do
      put blog_url blog, params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to blog_path(blog)
    end

    it "destroys blog" do
      assert_difference('Blog.count', -1) do
        delete blog_url blog
      end

      assert_redirected_to blogs_path
    end
  end

  ################################################################################
  # USER ROLE
  ################################################################################
  describe "Singular: Make sure plain users can't see what they shouldn't." do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: false)
      create_user_and_login
    end

    let(:blog) { blogs :one }

    it "plain user can see index" do
      get blogs_url
      assert_response :success
      assert_not_equal 0, Blog.count
    end

    it "gets permission denied on new" do
      get new_blog_url
      assert_response 302
      flash[:notice].must_equal "Permission Denied"
    end

    it "gets forbidden and no redirect with json format on new" do
      assert_webservice_is_forbiddden do |format|
        get new_blog_url(format: format)
      end
    end

    it "doesn't allow plain user to create blog post" do
      assert_no_difference('Blog.count') do
        post blogs_url, params: { blog: { content: blog.content, title: blog.title } }
        assert_redirected_to root_path

        assert_webservice_is_forbiddden do |format|
          post blogs_url(format: format), params: { blog: { content: blog.content, title: blog.title } }
        end
      end
    end

    it "can see show blog" do
      get blog_url blog
      assert_response :success
    end

    it "can't get to edit page" do
      get edit_blog_url blog
      assert_response 302
    end

    it "can't update blog" do
      put blog_url blog, params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to root_path 

      assert_webservice_is_forbiddden do |format|
        put blog_url(blog, format: format), params: { blog: { content: blog.content, title: blog.title } }
      end
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count') do
        delete blog_url blog
        assert_redirected_to root_path

        assert_webservice_is_forbiddden do |format|
          delete blog_url blog
          delete blog_url(blog, format: format)
        end
      end
    end
  end

  #################################################################################
  # COMPANY_ADMIN ROLE
  #################################################################################
  describe "Singular: Test that everything works if company_admin is logged in" do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: false)
      create_company_admin_and_login
    end

    let(:blog) { blogs :one }

    it "gets index" do
      get blogs_url
      assert_response :success
      assert_not_equal 0, Blog.count
    end

    it "gets new" do
      get new_blog_url
      assert_response :success
    end

    it "creates blog" do
      assert_difference('Blog.count') do
        post blogs_url, params: { blog: { content: blog.content, title: blog.title } }
      end

      assert_redirected_to blog_path(Blog.last)
    end

    it "shows blog" do
      get blog_url blog
      assert_response :success
    end

    it "gets edit" do
      get edit_blog_url blog
      assert_response :success
    end

    it "updates blog" do
      put blog_url blog, params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to blog_path(blog)
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count', -1) do
        delete blog_url blog
      end

      assert_redirected_to root_path
    end
  end

  private

  def assert_webservice_is_forbiddden(&block)
    [:js, :json, :xml].each do |format|
      block.call format
      assert_response :forbidden
    end
  end
end
