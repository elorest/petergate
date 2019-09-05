require "test_helper"

describe BlogsController do
  ################################################################################
  # ADMIN ROLE
  ################################################################################
  describe "Multiple: Test that everything works if admin is logged in" do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: true)
      create_admin_and_login
    end

    let(:blog) { blogs :one }

    it "gets index" do
      get root_path
      assert_response :success
      assert_not_nil :blog
    end

    it "gets new" do
      get new_blog_path
      assert_response :success
    end

    it "creates blog" do
      assert_difference('Blog.count') do
        post blogs_path, params: { blog: { content: blog.content, title: blog.title } }
      end

      assert_redirected_to blog_path(Blog.last)
    end

    it "shows blog" do
      get blog_path(blog)
      assert_response :success
    end

    it "gets edit" do
      get edit_blog_path(blog)
      assert_response :success
    end

    it "updates blog" do
      put blog_path(blog), params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to blog_path(blog)
    end

    it "destroys blog" do
      assert_difference('Blog.count', -1) do
        delete blog_path(blog)
      end

      assert_redirected_to blogs_path
    end
  end

  ################################################################################
  # USER ROLE
  ################################################################################
  describe "Multiple: Make sure plain users can't see what they shouldn't." do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: true)
      create_user_and_login
    end

    let(:blog) { blogs :one }

    it "plain user can see index" do
      get root_path
      assert_response :success
      assert_not_nil blog
    end

    it "gets permission denied on new" do
      get new_blog_path
      assert_response 302
      flash[:notice].must_equal "Permission Denied"
    end

    it "gets forbidden and no redirect with json format on new" do
      assert_webservice_is_forbiddden do |format|
        get new_blog_path, headers: { 'Accept': Mime[format].to_s, 'Content-Type': Mime[format].to_s }
      end
    end

    it "doesn't allow plain user to create blog post" do
      assert_no_difference('Blog.count') do
        post blogs_path, params: { blog: { content: blog.content, title: blog.title } }
        assert_redirected_to root_path

        assert_webservice_is_forbiddden do |format|
          post blogs_path, params: { blog: { 'content': blog.content, 'title': blog.title } }.to_json, headers: { 'Accept': Mime[format].to_s, 'Content-Type': Mime[format].to_s}
        end
      end
    end

    it "can see show blog" do
      get blog_path(blog)
      assert_response :success
    end

    it "can't get to edit page" do
      get edit_blog_path(blog)
      assert_response 302
    end

    it "can't update blog" do
      put blog_path(blog), params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to root_path 

      assert_webservice_is_forbiddden do |format|
        put blog_path(blog), params: {blog: { content: blog.content, title: blog.title }}.to_json , headers: { 'Accept': Mime[format].to_s, 'Content-Type': Mime[format].to_s }
      end
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count') do
        delete blog_path(blog)
        assert_redirected_to root_path
      end
      assert_webservice_is_forbiddden do |format|
        delete blog_path(blog), headers: { 'Accept': Mime[format].to_s, 'Content-Type': Mime[format].to_s }
      end
    end
  end

  ################################################################################
  # GUEST ROLE
  ################################################################################
  describe "Multiple: Make sure guests can't see what they shouldn't." do
    let(:blog) { blogs :one }

    it "guest can see index" do
      get root_path
      assert_response :success
      assert_not_nil blog
    end

    it "gets permission denied on new" do
      get new_blog_path
      assert_redirected_to "/employees/sign_in"
    end

    it "json gets permission denied on new" do
      assert_webservice_is_unauthorized do |format|
        get new_blog_path, headers: {'Accept': Mime[format].to_s, 'Content-Type': Mime[format].to_s}
      end
    end

    it "doesn't allow plain user to create blog post" do
      assert_no_difference('Blog.count') do
        post blogs_path, params: { blog: { content: blog.content, title: blog.title } }
        assert_redirected_to "/employees/sign_in"
      end
    end

    it "doesn't show blog" do
      get blog_path(blog)
      assert_response 302
    end

    it "can't get to edit page" do
      get edit_blog_path(blog)
      assert_response 302
    end

    it "can't update blog" do
      put blog_path(blog), params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to "/employees/sign_in"
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count') do
        delete blog_path(blog)
        assert_redirected_to "/employees/sign_in"
      end
    end
  end

  ################################################################################
  # COMPANY_ADMIN ROLE
  ################################################################################
  describe "Multiple: Test that everything works if company_admin is logged in" do
    before do
      Employee.petergate(roles: [:root_admin, :company_admin], multiple: true)
      create_company_admin_and_login
    end

    let(:blog) { blogs :one }

    it "gets index" do
      get root_path
      assert_response :success
      assert_not_nil :blogs
    end

    it "gets new" do
      get new_blog_path
      assert_response :success
    end

    it "creates blog" do
      assert_difference('Blog.count') do
        post blogs_path, params: { blog: { content: blog.content, title: blog.title } }
      end

      assert_redirected_to blog_path(Blog.last)
    end

    it "shows blog" do
      get blog_path(blog)
      assert_response :success
    end

    it "gets edit" do
      get edit_blog_path(blog)
      assert_response :success
    end

    it "updates blog" do
      put blog_path(blog), params: { blog: { content: blog.content, title: blog.title } }
      assert_redirected_to blog_path(blog)
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count', -1) do
        delete blog_path(id: blog)
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

  def assert_webservice_is_unauthorized(&block)
    [:js, :json, :xml].each do |format|
      block.call format
      assert_response :unauthorized
    end
  end
end

