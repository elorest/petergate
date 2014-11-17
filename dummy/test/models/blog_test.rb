require "test_helper"

describe Blog do
  let(:blog) { Blog.new }

  it "must be valid" do
    blog.must_be :valid?
  end
end
