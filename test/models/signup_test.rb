require "test_helper"

class SignupTest < ActiveSupport::TestCase
  test "first signup is staff" do
    Account.stubs(:none?).returns(true)

    Signup.new(email_address: "operator@example.com").create_identity

    assert Identity.find_by(email_address: "operator@example.com").staff?
  end

  test "subsequent signups are not staff" do
    Signup.new(email_address: "newcomer@example.com").create_identity

    assert_not Identity.find_by(email_address: "newcomer@example.com").staff?
  end
end
