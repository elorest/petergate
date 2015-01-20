require "test_helper"

describe "ActionController::Base" do
  it "must have ALLREST as an array" do
    ActionController::Base::ALLREST.must_be_instance_of(Array)
  end
end
