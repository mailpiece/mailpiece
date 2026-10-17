require "test_helper"

class Account::SenderTest < ActiveSupport::TestCase
  test "complete with a name, an address and a transport" do
    assert account_senders(:davids).complete?
    assert_equal "Leo <leo@newsletter.example>", account_senders(:davids).from
  end

  test "missing names what is blank" do
    sender = accounts(:davids_account).build_sender

    assert_not sender.complete?
    assert_equal %i[ from_name from_address transport ], sender.missing

    sender.from_name = "Leo"
    sender.from_address = "leo@newsletter.example"
    assert_equal %i[ transport ], sender.missing

    sender.transport = "relay"
    assert sender.complete?
  end

  test "a newsletter that stops sending is not set up" do
    sender = account_senders(:davids)

    sender.stop_sending

    assert_equal %i[ transport ], sender.reload.missing
    assert_nil sender.relay_url
    assert_nil sender.relay_token
  end

  test "a relay needs an address and a token" do
    sender = account_senders(:davids)
    sender.stop_sending

    assert_not sender.use_relay(relay_url: "")
    assert_equal [ "Relay address can't be blank", "Token can't be blank" ], sender.errors.full_messages
    assert_nil sender.reload.transport

    assert_not sender.use_relay(relay_url: "relay.example", relay_token: "token")
    assert_equal [ "Relay address is invalid" ], sender.errors.full_messages

    assert sender.use_relay(relay_url: "https://relay.example/messages", relay_token: "token")
    assert sender.reload.relay?
  end

  test "an SMTP server needs an address and a port, and asks for no sign-in" do
    sender = account_senders(:davids)

    assert_not sender.use_smtp_server(smtp_address: "smtp.example")
    assert_equal [ "Port can't be blank" ], sender.errors.full_messages

    assert sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)
    assert sender.reload.smtp?
    assert_nil sender.smtp_username
    assert_nil sender.smtp_password
  end

  test "an SMTP password with no username is dropped, since it signs nothing in" do
    sender = account_senders(:davids)

    sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: " ", smtp_password: "secret")

    assert_nil sender.reload.smtp_username
    assert_nil sender.smtp_password
  end

  test "using one transport forgets the other's settings" do
    sender = account_senders(:davids)

    sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "secret")
    assert_nil sender.reload.relay_url
    assert_nil sender.relay_token

    sender.use_relay(relay_url: "https://relay.example/messages", relay_token: "token")
    assert_equal [ nil ], sender.reload.attributes.values_at(*Account::Sender::SMTP_ATTRIBUTES.map(&:to_s)).uniq
  end

  test "stop_sending forgets every transport setting, credentials included" do
    sender = account_senders(:davids)
    sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "secret")

    sender.stop_sending

    assert_equal [ nil ], sender.reload.attributes.values_at(*Account::Sender::TRANSPORT_ATTRIBUTES.map(&:to_s)).uniq
  end

  test "its token and password are stored encrypted" do
    sender = account_senders(:davids)
    sender.stop_sending
    sender.use_relay(relay_url: "https://relay.example/messages", relay_token: "own_token")

    assert_not_includes sender.reload.relay_token_before_type_cast, "own_token"
    assert_equal "own_token", sender.relay_token

    sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")
    assert_not_includes sender.reload.smtp_password_before_type_cast, "own_password"
  end

  test "its credentials stay out of what it shows of itself" do
    sender = account_senders(:davids)
    sender.stop_sending
    sender.update!(relay_token: "own_token", smtp_password: "own_password")

    assert_not_includes sender.inspect, "own_token"
    assert_not_includes sender.inspect, "own_password"
  end

  test "reply_to carries the from name, and is nothing while the address is blank" do
    sender = account_senders(:davids)
    assert_nil sender.reply_to

    sender.update!(reply_to_address: " Editor@Newsletter.example ")
    assert_equal "editor@newsletter.example", sender.reply_to_address
    assert_equal "Leo <editor@newsletter.example>", sender.reply_to
    assert sender.complete?
  end

  test "a reply to address has to be an email address" do
    sender = account_senders(:davids)

    assert_not sender.update(reply_to_address: "nope")
    assert_equal [ "Reply to is invalid" ], sender.errors.full_messages
  end

  test "domain is the from address's" do
    assert_equal "newsletter.example", account_senders(:davids).domain
  end
end
