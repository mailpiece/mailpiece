# What a newsletter's own mail leaves through. None holds settings of its own: each message brings them (MailTransport).
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method :relay, Relay::DeliveryMethod
  ActionMailer::Base.add_delivery_method :smtp_relay, Smtp::DeliveryMethod
  ActionMailer::Base.add_delivery_method :unconfigured, MailTransport::Unconfigured
end
