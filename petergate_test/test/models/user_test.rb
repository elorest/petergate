require "test_helper"

describe Blog do
  let(:user) {
    User.petergate(roles: [:root_admin, :company_admin], multiple: false)
    User.create(email: "company_admin2@example.com", password: "password1", password_confirmation: "password1", role: :company_admin)
  }

  it "must be valid" do
    user.must_be :valid?
  end
end
