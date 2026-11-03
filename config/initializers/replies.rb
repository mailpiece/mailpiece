Rails.application.configure do
  config.after_initialize do
    # The relay ingress takes mail only under its password, so without one no domain is set.
    Account.replies_domain = ENV["REPLIES_DOMAIN"] if ENV["RAILS_INBOUND_EMAIL_PASSWORD"].present?
  end
end
