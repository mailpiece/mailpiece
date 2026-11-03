require "test_helper"

class Account::RepliesReceivableTest < ActiveSupport::TestCase
  test "receiving replies while a replies domain is set" do
    assert_not Account.receiving_replies?

    receive_replies
    assert Account.receiving_replies?
  end
end
