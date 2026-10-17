require "test_helper"

class Account::OutgoingMailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "show offers a relay or an SMTP server while the newsletter has neither" do
    account_senders(:davids).stop_sending

    get account_outgoing_mail_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select ".blank-slate", text: /Not set up\./
    assert_select ".blank-slate a[href=?]", edit_account_sender_relay_path, text: "a relay"
    assert_select ".blank-slate a[href=?]", edit_account_sender_smtp_server_path, text: "an SMTP server"
    assert_select "li.row", count: 0
  end

  test "show offers the same before there is a sender" do
    account_senders(:davids).destroy

    get account_outgoing_mail_path

    assert_response :success
    assert_select ".blank-slate a[href=?]", edit_account_sender_relay_path
  end

  test "show has the relay as a row to edit or remove, and never its token" do
    get account_outgoing_mail_path

    assert_response :success
    assert_select "li.row .row__title", text: "Over a relay"
    assert_select "li.row .row__meta", text: "https://relay.example/messages · Token set"
    assert_select "li.row form[action=?] input[name=_method][value=delete]", account_sender_relay_path
    assert_select "li.row a[href=?]", edit_account_sender_relay_path, text: "Edit"
    assert_select ".blank-slate", count: 0
    assert_not_includes response.body, "stream_token"
  end

  test "show has an SMTP server as a row, and never its password" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 465, smtp_username: "leo", smtp_password: "own_password")

    get account_outgoing_mail_path

    assert_select "li.row .row__title", text: "Over an SMTP server"
    assert_select "li.row .row__meta", text: "smtp.example:465 · Password set"
    assert_select "li.row form[action=?]", account_sender_smtp_server_path
    assert_select "li.row a[href=?]", edit_account_sender_smtp_server_path, text: "Edit"
    assert_not_includes response.body, "own_password"

    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "")

    get account_outgoing_mail_path

    assert_select "li.row .row__meta", text: "smtp.example:587 · No sign-in"
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get account_outgoing_mail_path

    assert_response :forbidden
  end
end
