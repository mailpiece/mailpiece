require "test_helper"

class SettingsHelperTest < ActionView::TestCase
  test "finishing sending leads to the Sending page while who it writes as is missing" do
    account_senders(:davids).update!(from_address: nil)
    assert_equal edit_account_sender_path, Current.account.reload.then { settings_path_to_finish_sending }

    account_senders(:davids).stop_sending
    assert_equal edit_account_sender_path, Current.account.reload.then { settings_path_to_finish_sending }

    account_senders(:davids).destroy
    assert_equal edit_account_sender_path, Current.account.reload.then { settings_path_to_finish_sending }
  end

  test "finishing sending leads to Outgoing mail when only the transport is missing" do
    account_senders(:davids).stop_sending

    assert_equal account_outgoing_mail_path, Current.account.reload.then { settings_path_to_finish_sending }
  end
end
