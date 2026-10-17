module MailTransportTestHelper
  extend ActiveSupport::Concern

  MAIL_TRANSPORTS = {
    relay: { transport: "relay", relay_url: "https://relay.example/messages", relay_token: "stream_token" },
    smtp: { transport: "smtp", smtp_address: "smtp.example", smtp_port: 587, smtp_username: "mailpiece", smtp_password: "smtp_password" },
    nothing: {}
  }

  SYSTEM_SMTP_SETTINGS = { address: "system.example", port: 587, user_name: "system", password: "system_password", authentication: "plain", tls: false }

  included do
    teardown do
      Rails.configuration.x.newsletter_mail.delivered_by_transport = nil
    end
  end

  # Tests send a newsletter's mail to the test mailer, as development opens it in the browser. This sets how the
  # davids newsletter's mail leaves, and has it delivered that way as production would.
  def send_mail_over(transport, **settings)
    columns = MAIL_TRANSPORTS.fetch(transport).merge(settings.transform_keys { |setting| setting.to_s.downcase.to_sym })
    account_senders(:davids).update_columns Account::Sender::TRANSPORT_ATTRIBUTES.index_with(nil).merge(columns)
    accounts(:davids_account).reload
    Rails.configuration.x.newsletter_mail.delivered_by_transport = true
  end

  # Production sends system mail over SMTP, and has nowhere to send a newsletter's mail with no transport,
  # where a test would keep both.
  def deliver_as_production
    delivery_method, ActionMailer::Base.delivery_method = ActionMailer::Base.delivery_method, :smtp
    smtp_settings, ActionMailer::Base.smtp_settings = ActionMailer::Base.smtp_settings, SYSTEM_SMTP_SETTINGS
    delivered_by_transport, Rails.configuration.x.newsletter_mail.delivered_by_transport = Rails.configuration.x.newsletter_mail.delivered_by_transport, true
    yield
  ensure
    ActionMailer::Base.delivery_method = delivery_method
    ActionMailer::Base.smtp_settings = smtp_settings
    Rails.configuration.x.newsletter_mail.delivered_by_transport = delivered_by_transport
  end
end
