# How a newsletter's own mail (issues, test issues, subscription confirmations) leaves the install, as
# NEWSLETTER_MAIL_* in ENV says. System mail is not its business: that goes over Action Mailer's own SMTP,
# set from SMTP_* in the environment, and nothing here reads those. Nothing checks the settings either: the
# newsletter sends with what it is given, and a message fails when it is tried if that is not enough.
class MailTransport
  class Unconfigured
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    def deliver!(mail)
      raise MailDelivery::Unavailable, "The newsletter's mail is not configured: " \
        "NEWSLETTER_MAIL_TRANSPORT must be smtp or relay"
    end
  end

  class << self
    def newsletter
      new
    end
  end

  def initialize(env = ENV)
    @env = env
  end

  def delivery_method
    if smtp?
      :smtp_relay
    elsif relay?
      :relay
    end
  end

  def settings
    if smtp?
      smtp_settings
    elsif relay?
      { url: value("RELAY_URL"), token: value("RELAY_TOKEN") }.compact
    else
      {}
    end
  end

  # The relay takes a message's key and sends it once however often it is posted, and with no transport
  # nothing real is sent. SMTP alone hands over a second copy when asked twice.
  def idempotent?
    !smtp?
  end

  private
    def smtp?
      value("TRANSPORT") == "smtp"
    end

    def relay?
      value("TRANSPORT") == "relay"
    end

    # An SMTP server that asks for no sign-in is given none: without a username there is nothing to authenticate with.
    def smtp_settings
      {
        address: value("SMTP_ADDRESS"),
        port: value("SMTP_PORT")&.to_i,
        user_name: value("SMTP_USERNAME"),
        password: value("SMTP_PASSWORD"),
        authentication: (value("SMTP_AUTHENTICATION") || "plain" if value("SMTP_USERNAME")),
        domain: value("SMTP_DOMAIN"),
        tls: tls?,
        enable_starttls: (:always unless tls?),
        openssl_verify_mode: value("SMTP_SSL_VERIFY_MODE")
      }.compact
    end

    # Without TLS from the first byte the session must upgrade before anything is said: a server that offers
    # no STARTTLS is not given the install's password in the clear.
    def tls?
      value("SMTP_TLS") == "true"
    end

    def value(setting)
      @env["NEWSLETTER_MAIL_#{setting}"].presence
    end
end
