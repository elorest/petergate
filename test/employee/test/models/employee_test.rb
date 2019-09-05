require "test_helper"

describe Employee do
  let(:employee) {
    Employee.petergate(roles: [:root_admin, :company_admin], multiple: false)
    Employee.create(email: "company_admin2@example.com", password: "password1", password_confirmation: "password1", role: :company_admin)
  }

  it "must be valid" do
    employee.must_be :valid?
  end
end
