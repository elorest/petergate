require "test_helper"

describe BlogsController do
  describe "Test that everything works if admin is logged in" do
    before do
      create_admin_and_login
    end

    let(:blog) { blogs :one }

    it "gets index" do
      get :index
      assert_response :success
      assert_not_nil assigns(:blogs)
    end

    it "gets new" do
      get :new
      assert_response :success
    end

    it "creates blog" do
      assert_difference('Blog.count') do
        post :create, blog: { content: blog.content, title: blog.title }
      end

      assert_redirected_to blog_path(assigns(:blog))
    end

    it "shows blog" do
      get :show, id: blog
      assert_response :success
    end

    it "gets edit" do
      get :edit, id: blog
      assert_response :success
    end

    it "updates blog" do
      put :update, id: blog, blog: { content: blog.content, title: blog.title }
      assert_redirected_to blog_path(assigns(:blog))
    end

    it "destroys blog" do
      assert_difference('Blog.count', -1) do
        delete :destroy, id: blog
      end

      assert_redirected_to blogs_path
    end
  end

  describe "Make sure plain users can't see what they shouldn't." do
    before do
      create_user_and_login
    end

    let(:blog) { blogs :one }

    it "plain user can see index" do
      get :index
      assert_response :success
      assert_not_nil assigns(:blogs)
    end

    it "gets permission denied on new" do
      get :new
      assert_response 302
      flash[:notice].must_equal "Permission Denied"

      assert_webservice_is_forbiddden do |format|
        get :new, format: format
      end
    end

    it "doesn't allow plain user to create blog post" do
      assert_no_difference('Blog.count') do
        post :create, blog: { content: blog.content, title: blog.title }
        assert_redirected_to root_path

        assert_webservice_is_forbiddden do |format|
          post :create, format: format, blog: { content: blog.content, title: blog.title }
        end
      end
    end

    it "doesn't show blog" do
      get :show, id: blog
      assert_response 302

      assert_webservice_is_forbiddden do |format|
        get :show, id: blog, format: format
      end
    end

    it "can't get to edit page" do
      get :edit, id: blog
      assert_response 302

      assert_webservice_is_forbiddden do |format|
        get :show, id: blog, format: format
      end
    end

    it "can't update blog" do
      put :update, id: blog, blog: { content: blog.content, title: blog.title }
      assert_redirected_to root_path 

      assert_webservice_is_forbiddden do |format|
        put :update, format: format, id: blog, blog: { content: blog.content, title: blog.title }
      end
    end

    it "can't destroy blog" do
      assert_no_difference('Blog.count') do
        delete :destroy, id: blog
        assert_redirected_to root_path

        assert_webservice_is_forbiddden do |format|
          put :update, format: format, id: blog, blog: { content: blog.content, title: blog.title }
        end
      end
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
