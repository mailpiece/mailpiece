require "test_helper"

class Account::WelcomingTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:davids_account)
  end

  test "start welcoming" do
    assert_not @account.welcoming?

    assert_difference -> { Account::Welcome.count }, 1 do
      @account.start_welcoming
    end

    assert @account.reload.welcoming?
  end

  test "start welcoming doesn't create duplicate welcomes" do
    @account.start_welcoming

    assert_no_difference -> { Account::Welcome.count } do
      @account.start_welcoming
    end
  end

  test "welcomes_visitors?" do
    @account.start_welcoming
    assert @account.welcomes_visitors?

    account_senders(:davids).update!(from_address: nil)
    assert_not @account.reload.welcomes_visitors?
  end

  test "stop welcoming" do
    @account.start_welcoming

    assert_difference -> { Account::Welcome.count }, -1 do
      @account.stop_welcoming
    end

    assert_not @account.reload.welcoming?
  end
end
