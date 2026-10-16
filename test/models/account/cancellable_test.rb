require "test_helper"

class Account::CancellableTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    @account = accounts(:davids_account)
  end

  test "cancel" do
    assert_difference -> { Account::Cancellation.count }, 1 do
      assert_enqueued_emails 1 do
        @account.cancel(initiated_by: users(:leo))
      end
    end

    assert @account.reload.cancelled?
    assert_equal users(:leo), @account.cancellation.initiated_by
  end

  test "cancel when not accepting signups" do
    Account.stubs(:accepting_signups?).returns(false)

    assert_no_difference -> { Account::Cancellation.count } do
      @account.cancel(initiated_by: users(:leo))
    end

    assert_not @account.reload.cancelled?
  end

  test "reactivate" do
    @account.cancel(initiated_by: users(:leo))

    @account.reactivate

    assert_not @account.reload.cancelled?
  end
end
