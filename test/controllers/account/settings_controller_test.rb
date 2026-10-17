require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "show lists a row for each page, with how it stands" do
    get account_settings_path

    assert_response :success
    assert_select "ul.rows li.row", count: 8
    assert_select "li.row a[href=?]", edit_account_newsletter_path, text: /Newsletter\s+Leo's Account/
    assert_select "li.row a[href=?]", edit_account_handle_path, text: /Handle\s+Pick an address/
    assert_select "li.row a[href=?]", edit_account_domain_path, text: /Domain\s+No domain/
    assert_select "li.row a[href=?]", edit_account_sender_path, text: /Sending\s+leo@newsletter.example/
    assert_select "li.row a[href=?]", account_outgoing_mail_path, text: /Outgoing mail\s+Over a relay at relay.example/
    assert_select "li.row a[href=?]", edit_account_subscribe_form_path, text: /Subscribe form/
    assert_select "li.row a[href=?]", account_welcome_path, text: /Welcome\s+Off/
    assert_select "li.row a[href=?]", user_path(users(:leo)), text: /Profile\s+Leo/
    assert_select "li.row .icon", count: 8
    assert_select ".site-header__link", text: /Profile/, count: 0
    assert_select "form[method=post]", count: 0
  end

  test "show says the address once it is picked" do
    accounts(:davids_account).update!(handle: "contractor-notes")

    get "/contractor-notes/account/settings"

    assert_response :success
    assert_select "li.row a[href=?]", "/contractor-notes/account/handle/edit", text: /http:\/\/www.example.com\/contractor-notes\//
  end

  test "show says which SMTP server a newsletter sends over" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)

    get account_settings_path

    assert_select "li.row a[href=?]", account_outgoing_mail_path, text: /Outgoing mail\s+Over SMTP at smtp.example/
  end

  test "show says when sending is not set up" do
    account_senders(:davids).update!(from_address: nil)

    get account_settings_path

    assert_select "li.row a[href=?]", edit_account_sender_path, text: /Sending\s+Not set up/
    assert_select "li.row a[href=?]", account_outgoing_mail_path, text: /Outgoing mail\s+Over a relay/

    account_senders(:davids).update!(from_address: "leo@newsletter.example")
    account_senders(:davids).stop_sending

    get account_settings_path

    assert_select "li.row a[href=?]", edit_account_sender_path, text: /Sending\s+Not set up/
    assert_select "li.row a[href=?]", account_outgoing_mail_path, text: /Outgoing mail\s+Not set up/
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get account_settings_path

    assert_response :forbidden
  end
end
