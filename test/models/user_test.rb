require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "deactivate" do
    user = users(:nonstaff)

    user.deactivate

    assert_not user.reload.active?
    assert_nil user.identity
  end
end
