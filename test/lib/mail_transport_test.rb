require "test_helper"

class MailTransportTest < ActiveSupport::TestCase
  setup do
    Rails.configuration.x.newsletter_mail.delivered_by_transport = true
    @sender = account_senders(:davids)
    @sender.stop_sending
  end

  test "the relay is posted to with the newsletter's own address and token" do
    @sender.use_relay(relay_url: "https://relay.example/7/messages", relay_token: "relay_token")

    assert_equal :relay, transport.delivery_method
    assert_equal({ url: "https://relay.example/7/messages", token: "relay_token" }, transport.settings)
  end

  test "SMTP signs in with the newsletter's username and password" do
    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "mailpiece", smtp_password: "secret")

    assert_equal :smtp_relay, transport.delivery_method
    assert_equal({ address: "smtp.example", port: 587, user_name: "mailpiece", password: "secret", authentication: "plain", enable_starttls: :always },
      transport.settings)
  end

  test "SMTP with no username asks for no sign-in" do
    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)

    assert_equal({ address: "smtp.example", port: 587, enable_starttls: :always }, transport.settings)
  end

  test "SMTP on port 465 is TLS from the first byte, and any other port must upgrade" do
    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 465)
    assert transport.settings[:tls]
    assert_not transport.settings.key?(:enable_starttls)

    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 2525)
    assert_equal :always, transport.settings[:enable_starttls]
    assert_not transport.settings.key?(:tls)
  end

  test "a newsletter with no transport is delivered by nothing that sends" do
    assert_equal :unconfigured, transport.delivery_method
    assert_empty transport.settings
    assert_equal :unconfigured, MailTransport.newsletter(Account.create!(name: "No Sender")).delivery_method
  end

  test "outside production the mail goes the environment's own way, whatever the transport" do
    Rails.configuration.x.newsletter_mail.delivered_by_transport = nil

    assert_nil transport.delivery_method
    assert_empty transport.settings

    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "secret")
    assert_nil transport.delivery_method
    assert_empty transport.settings
    assert_not transport.idempotent?
  end

  test "nothing is delivered for a newsletter with no transport, and the error says where to set one" do
    error = assert_raises(MailDelivery::Unavailable) do
      MailTransport::Unconfigured.new({}).deliver!(Mail.new)
    end

    assert_equal "The newsletter has no transport: set one on its Sending page", error.message
  end

  test "a message submitted twice goes out twice over SMTP alone" do
    assert transport.idempotent?

    @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)
    assert_not transport.idempotent?

    @sender.stop_sending
    assert transport.idempotent?
  end

  test "the newsletter never borrows the system's SMTP settings" do
    deliver_as_production do
      @sender.use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)
      assert_equal({ address: "smtp.example", port: 587, enable_starttls: :always }, transport.settings)

      @sender.stop_sending
      assert_equal :unconfigured, transport.delivery_method
      assert_empty transport.settings
    end
  end

  private
    def transport
      MailTransport.newsletter(accounts(:davids_account).reload)
    end
end
