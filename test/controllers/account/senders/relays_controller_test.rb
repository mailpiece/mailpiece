require "test_helper"

class Account::Senders::RelaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the relay's form under Outgoing mail, with an empty token" do
    account_senders(:davids).stop_sending

    get edit_account_sender_relay_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_outgoing_mail_path, text: "Outgoing mail"
    assert_select "form[action=?]", account_sender_relay_path
    assert_select "input[type=url][name='account_sender[relay_url]']"
    assert_select "input[type=password][name='account_sender[relay_token]']:not([value])"
  end

  test "edit of a set relay has its address, and no token field" do
    get edit_account_sender_relay_path

    assert_response :success
    assert_select "input[name='account_sender[relay_url]'][value=?]", "https://relay.example/messages"
    assert_select "input[name='account_sender[relay_token]']", count: 0
    assert_select "p", text: /Token set\. It can.t be shown again\. To change it, delete the relay/
    assert_not_includes response.body, "stream_token"
  end

  test "update of a set relay changes its address and keeps its token" do
    patch account_sender_relay_path, params: { account_sender: { relay_url: "https://own.example/messages" } }

    assert_redirected_to account_outgoing_mail_path
    assert_equal [ "relay", "https://own.example/messages", "stream_token" ], account_senders(:davids).reload.attributes.values_at("transport", "relay_url", "relay_token")

    patch account_sender_relay_path, params: { relay_url: "https://own.example/v2/messages" }, as: :json

    assert_response :success
    assert_equal "https://own.example/v2/messages", response.parsed_body["relay_url"]
    assert_equal "stream_token", account_senders(:davids).reload.relay_token
  end

  test "a token sent for a set relay is refused, and nothing changes" do
    patch account_sender_relay_path, params: { account_sender: { relay_url: "https://own.example/messages", relay_token: "other_token" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Token can't be changed: remove the relay and set it up again/

    patch account_sender_relay_path, params: { relay_token: "other_token" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be changed: remove the relay and set it up again" ], response.parsed_body["relay_token"]
    assert_equal [ "https://relay.example/messages", "stream_token" ], account_senders(:davids).reload.attributes.values_at("relay_url", "relay_token")
  end

  test "update sends over the relay, and forgets an SMTP server" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_password: "own_password")

    patch account_sender_relay_path, params: { account_sender: { relay_url: "https://own.example/messages", relay_token: "own_token" } }

    assert_redirected_to account_outgoing_mail_path
    sender = account_senders(:davids).reload
    assert sender.relay?
    assert_equal [ "https://own.example/messages", "own_token" ], [ sender.relay_url, sender.relay_token ]
    assert_nil sender.smtp_address
    assert_nil sender.smtp_password
  end

  test "update with no token where none is stored shows the form again" do
    account_senders(:davids).stop_sending

    patch account_sender_relay_path, params: { account_sender: { relay_url: "https://own.example/messages", relay_token: "" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Token can't be blank/
    assert_nil account_senders(:davids).reload.transport
  end

  test "update as JSON answers with the sending settings, and never the token" do
    account_senders(:davids).stop_sending

    patch account_sender_relay_path, params: { relay_url: "https://own.example/messages", relay_token: "own_token" }, as: :json

    assert_response :success
    assert_equal "relay", response.parsed_body["transport"]
    assert_equal "https://own.example/messages", response.parsed_body["relay_url"]
    assert_not response.parsed_body.key?("relay_token")
    assert_not_includes response.body, "own_token"
    assert_equal "own_token", account_senders(:davids).reload.relay_token
  end

  test "update as JSON that does not save answers with the errors" do
    account_senders(:davids).stop_sending

    patch account_sender_relay_path, params: { relay_url: "https://own.example/messages" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["relay_token"].present?
  end

  test "destroy forgets the relay, and the newsletter is no longer set up" do
    delete account_sender_relay_path

    assert_redirected_to account_outgoing_mail_path
    assert_equal [ nil ], account_senders(:davids).reload.attributes.values_at(*Account::Sender::TRANSPORT_ATTRIBUTES.map(&:to_s)).uniq
    assert_not accounts(:davids_account).reload.sends_mail?
  end

  test "destroy as JSON answers with no content" do
    delete account_sender_relay_path(format: :json)

    assert_response :no_content
    assert_nil account_senders(:davids).reload.relay_token
  end
end
