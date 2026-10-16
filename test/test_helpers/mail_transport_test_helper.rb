module MailTransportTestHelper
  MAIL_TRANSPORTS = {
    relay: { "TRANSPORT" => "relay", "RELAY_URL" => "https://relay.example/messages", "RELAY_TOKEN" => "stream_token" },
    smtp: { "TRANSPORT" => "smtp", "SMTP_ADDRESS" => "smtp.example", "SMTP_PORT" => "587", "SMTP_USERNAME" => "mailpiece", "SMTP_PASSWORD" => "smtp_password" },
    nothing: {}
  }

  SYSTEM_SMTP_SETTINGS = { address: "system.example", port: 587, user_name: "system", password: "system_password", authentication: "plain", tls: false }

  # Tests run with no transport for the newsletter. This sets one, for the test, as NEWSLETTER_MAIL_* would.
  def send_mail_over(transport, **settings)
    env = MAIL_TRANSPORTS.fetch(transport).merge(settings.stringify_keys).transform_keys { |setting| "NEWSLETTER_MAIL_#{setting}" }
    MailTransport.stubs(:newsletter).returns(MailTransport.new(env))
  end

  # Production sends system mail over SMTP, and has nowhere to send a newsletter's mail with no transport,
  # where a test would keep both.
  def deliver_as_production
    delivery_method, ActionMailer::Base.delivery_method = ActionMailer::Base.delivery_method, :smtp
    smtp_settings, ActionMailer::Base.smtp_settings = ActionMailer::Base.smtp_settings, SYSTEM_SMTP_SETTINGS
    Rails.configuration.x.newsletter_mail.fallback_delivery_method = :unconfigured
    yield
  ensure
    ActionMailer::Base.delivery_method = delivery_method
    ActionMailer::Base.smtp_settings = smtp_settings
    Rails.configuration.x.newsletter_mail.fallback_delivery_method = nil
  end

  def while_offline
    Rails.configuration.x.offline = true
    yield
  ensure
    Rails.configuration.x.offline = false
  end
end
