require "test_helper"

class Account::Senders::SmtpServersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the SMTP server's form under Outgoing mail, with port 587 on a fresh form" do
    get edit_account_sender_smtp_server_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_outgoing_mail_path, text: "Outgoing mail"
    assert_select "form[action=?]", account_sender_smtp_server_path
    assert_select "input[name='account_sender[smtp_address]']"
    assert_select "input[name='account_sender[smtp_port]'][value=?]", "587"
    assert_select "input[name='account_sender[smtp_username]']"
    assert_select "input[type=password][name='account_sender[smtp_password]']:not([value])"
  end

  test "edit of a set SMTP server has its server, port and username, and no password field" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 465, smtp_username: "leo", smtp_password: "own_password")

    get edit_account_sender_smtp_server_path

    assert_response :success
    assert_select "input[name='account_sender[smtp_address]'][value=?]", "smtp.example"
    assert_select "input[name='account_sender[smtp_port]'][value=?]", "465"
    assert_select "input[name='account_sender[smtp_username]'][value=?]", "leo"
    assert_select "input[name='account_sender[smtp_password]']", count: 0
    assert_select "p", text: /Password set\. It can.t be shown again\. To change it, delete the SMTP server/
    assert_not_includes response.body, "own_password"
  end

  test "update of a set SMTP server changes its server and username and keeps its password" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")

    patch account_sender_smtp_server_path, params: { account_sender: { smtp_address: "mail.example", smtp_port: "465", smtp_username: "editor" } }

    assert_redirected_to account_outgoing_mail_path
    assert_equal [ "mail.example", 465, "editor", "own_password" ],
      account_senders(:davids).reload.attributes.values_at("smtp_address", "smtp_port", "smtp_username", "smtp_password")
  end

  test "a blanked username drops the password of a set SMTP server" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")

    patch account_sender_smtp_server_path, params: { smtp_username: "" }, as: :json

    assert_response :success
    assert_nil account_senders(:davids).reload.smtp_username
    assert_nil account_senders(:davids).smtp_password
  end

  test "a password sent for a set SMTP server is refused, and nothing changes" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")

    patch account_sender_smtp_server_path, params: { smtp_address: "mail.example", smtp_password: "other_password" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be changed: remove the SMTP server and set it up again" ], response.parsed_body["smtp_password"]
    assert_equal [ "smtp.example", "own_password" ], account_senders(:davids).reload.attributes.values_at("smtp_address", "smtp_password")
  end

  test "update sends over the SMTP server, and forgets the relay" do
    patch account_sender_smtp_server_path, params: { account_sender: { smtp_address: "smtp.example", smtp_port: "587", smtp_username: "", smtp_password: "" } }

    assert_redirected_to account_outgoing_mail_path
    sender = account_senders(:davids).reload
    assert sender.smtp?
    assert_equal [ "smtp.example", 587 ], [ sender.smtp_address, sender.smtp_port ]
    assert_nil sender.relay_url
    assert_nil sender.relay_token
  end

  test "setting up an SMTP server with a username needs its password" do
    patch account_sender_smtp_server_path, params: { account_sender: { smtp_address: "smtp.example", smtp_port: "587", smtp_username: "leo", smtp_password: "" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Password can't be blank/
    assert account_senders(:davids).reload.relay?
  end

  test "update with no server shows the form again" do
    patch account_sender_smtp_server_path, params: { account_sender: { smtp_address: "", smtp_port: "587" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Server can't be blank/
    assert account_senders(:davids).reload.relay?
  end

  test "update as JSON answers with the sending settings, and never the password" do
    patch account_sender_smtp_server_path, params: { smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password" }, as: :json

    assert_response :success
    assert_equal({ "transport" => "smtp", "relay_url" => nil, "smtp_address" => "smtp.example", "smtp_port" => 587, "smtp_username" => "leo" },
      response.parsed_body.to_h.slice("transport", "relay_url", "smtp_address", "smtp_port", "smtp_username"))
    assert_not response.parsed_body.key?("smtp_password")
    assert_not_includes response.body, "own_password"
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_sender_smtp_server_path, params: { smtp_address: "smtp.example" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["smtp_port"].present?
  end

  test "destroy forgets the SMTP server, credentials included" do
    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")

    delete account_sender_smtp_server_path

    assert_redirected_to account_outgoing_mail_path
    assert_equal [ nil ], account_senders(:davids).reload.attributes.values_at(*Account::Sender::TRANSPORT_ATTRIBUTES.map(&:to_s)).uniq
  end

  test "destroy as JSON answers with no content" do
    delete account_sender_smtp_server_path(format: :json)

    assert_response :no_content
    assert_nil account_senders(:davids).reload.transport
  end
end
