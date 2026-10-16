require "test_helper"

class Identity::JoinableTest < ActiveSupport::TestCase
  test "join" do
    identity = Identity.create!(email_address: "outsider@example.com")

    assert_difference -> { User.count }, 1 do
      assert identity.join(accounts(:davids_account))
    end

    user = identity.users.find_by!(account: accounts(:davids_account))
    assert_equal identity.email_address, user.name
  end

  test "join with name" do
    identity = Identity.create!(email_address: "named@example.com")

    assert identity.join(accounts(:davids_account), name: "Named Joiner")

    user = identity.users.find_by!(account: accounts(:davids_account))
    assert_equal "Named Joiner", user.name
  end

  test "join returns false if already member" do
    identity = identities(:leo)

    assert_no_difference -> { User.count } do
      assert_not identity.join(accounts(:davids_account))
    end
  end
end
