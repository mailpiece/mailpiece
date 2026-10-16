require "test_helper"

class MailTransportTest < ActiveSupport::TestCase
  RELAY = { "TRANSPORT" => "relay", "RELAY_URL" => "https://relay.example/7/messages", "RELAY_TOKEN" => "relay_token" }
  SMTP = { "TRANSPORT" => "smtp", "SMTP_ADDRESS" => "smtp.example", "SMTP_PORT" => "587", "SMTP_USERNAME" => "mailpiece", "SMTP_PASSWORD" => "secret" }

  # What production reads for system mail, which is none of the newsletter's business.
  SYSTEM_SMTP = { "SMTP_ADDRESS" => "system.example", "SMTP_PORT" => "465", "SMTP_DOMAIN" => "system.example", "SMTP_USERNAME" => "system",
    "SMTP_PASSWORD" => "system_password", "SMTP_AUTHENTICATION" => "login", "SMTP_TLS" => "true", "SMTP_SSL_VERIFY_MODE" => "none" }

  test "the relay is posted to with the newsletter's own address and token" do
    assert_equal :relay, transport(RELAY).delivery_method
    assert_equal({ url: "https://relay.example/7/messages", token: "relay_token" }, transport(RELAY).settings)
  end

  test "the relay with a setting left out is still the relay, with what it was given" do
    assert_equal :relay, transport(RELAY.except("RELAY_TOKEN")).delivery_method
    assert_equal({ url: "https://relay.example/7/messages" }, transport(RELAY.except("RELAY_TOKEN")).settings)
    assert_empty transport("TRANSPORT" => "relay").settings
  end

  test "SMTP delivers with the install's own sign-in" do
    assert_equal :smtp_relay, transport(SMTP).delivery_method
    assert_equal({ address: "smtp.example", port: 587, user_name: "mailpiece", password: "secret", authentication: "plain", tls: false, enable_starttls: :always },
      transport(SMTP).settings)
  end

  test "SMTP with no username or password is a relay that asks for no sign-in" do
    relay = SMTP.except("SMTP_USERNAME", "SMTP_PASSWORD")

    assert_equal :smtp_relay, transport(relay).delivery_method
    assert_equal({ address: "smtp.example", port: 587, tls: false, enable_starttls: :always }, transport(relay).settings)
    assert_equal({ address: "smtp.example", port: 587, tls: false, enable_starttls: :always }, transport(relay.merge("SMTP_AUTHENTICATION" => "login")).settings)
  end

  test "SMTP takes the optional settings of a Rails setup" do
    settings = transport(SMTP.merge("SMTP_PORT" => "465", "SMTP_AUTHENTICATION" => "login", "SMTP_DOMAIN" => "mailpiece.example",
      "SMTP_TLS" => "true", "SMTP_SSL_VERIFY_MODE" => "none")).settings

    assert_equal 465, settings[:port]
    assert_equal "login", settings[:authentication]
    assert_equal "mailpiece.example", settings[:domain]
    assert settings[:tls]
    assert_not settings.key?(:enable_starttls)
    assert_equal "none", settings[:openssl_verify_mode]
  end

  test "the newsletter never borrows the system's SMTP settings" do
    assert_nil MailTransport.new(SYSTEM_SMTP).delivery_method
    assert_empty MailTransport.new(SYSTEM_SMTP).settings

    over_smtp = MailTransport.new(SYSTEM_SMTP.merge("NEWSLETTER_MAIL_TRANSPORT" => "smtp"))
    assert_equal :smtp_relay, over_smtp.delivery_method
    assert_equal({ tls: false, enable_starttls: :always }, over_smtp.settings)

    assert_equal transport(SMTP).settings, MailTransport.new(SYSTEM_SMTP.merge(env_for(SMTP))).settings
    assert_equal transport(RELAY).settings, MailTransport.new(SYSTEM_SMTP.merge(env_for(RELAY))).settings
  end

  test "a transport left unset, or set to a name nobody knows, names no delivery method and no settings" do
    [ {}, { "TRANSPORT" => " " }, { "TRANSPORT" => "api" }, RELAY.merge("TRANSPORT" => "resend"), RELAY.except("TRANSPORT") ].each do |settings|
      assert_nil transport(settings).delivery_method
      assert_empty transport(settings).settings
    end
  end

  test "a message submitted twice goes out twice over SMTP alone" do
    assert transport(RELAY).idempotent?
    assert_not transport(SMTP).idempotent?
    assert transport({}).idempotent?
  end

  test "nothing is delivered for a newsletter that is not configured, and the error says what to set" do
    error = assert_raises(MailDelivery::Unavailable) do
      MailTransport::Unconfigured.new(transport({}).settings).deliver!(Mail.new)
    end

    assert_equal "The newsletter's mail is not configured: NEWSLETTER_MAIL_TRANSPORT must be smtp or relay", error.message
  end

  test "tests read none of the mail settings of whoever runs them" do
    assert_nil MailTransport.newsletter.delivery_method
  end

  private
    def transport(settings)
      MailTransport.new(env_for(settings))
    end

    def env_for(settings)
      settings.transform_keys { |setting| "NEWSLETTER_MAIL_#{setting}" }
    end
end
