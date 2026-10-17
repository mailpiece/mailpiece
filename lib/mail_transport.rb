# How a newsletter's own mail (issues, test issues, confirmations, journey emails) leaves: over the relay or SMTP
# server set on its Sending page. System mail is not its business: that goes over Action Mailer's own SMTP, set
# from SMTP_* in the environment, and nothing here reads those.
class MailTransport
  class Unconfigured
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    def deliver!(mail)
      raise MailDelivery::Unavailable, "The newsletter has no transport: set one on its Sending page"
    end
  end

  class << self
    def newsletter(account)
      new(account.sender)
    end
  end

  def initialize(sender)
    @sender = sender
  end

  # Only production delivers through the newsletter's transport, and there a newsletter with none fails rather
  # than leave over the system's SMTP. Elsewhere the mail goes the environment's own way, with that way's own settings.
  def delivery_method
    if delivered_by_transport?
      if smtp?
        :smtp_relay
      elsif relay?
        :relay
      else
        :unconfigured
      end
    end
  end

  def settings
    if delivered_by_transport? && smtp?
      smtp_settings
    elsif delivered_by_transport? && relay?
      { url: @sender.relay_url, token: @sender.relay_token }
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
    def delivered_by_transport?
      Rails.configuration.x.newsletter_mail.delivered_by_transport
    end

    def smtp?
      @sender&.smtp?
    end

    def relay?
      @sender&.relay?
    end

    def smtp_settings
      { address: @sender.smtp_address, port: @sender.smtp_port }.merge(sign_in_settings, tls_settings)
    end

    # An SMTP server that asks for no sign-in is given none: without a username there is nothing to authenticate with.
    def sign_in_settings
      if @sender.smtp_username.present?
        { user_name: @sender.smtp_username, password: @sender.smtp_password, authentication: "plain" }
      else
        {}
      end
    end

    # Without TLS from the first byte the session must upgrade before anything is said: a server that offers
    # no STARTTLS is not given the password in the clear.
    def tls_settings
      if @sender.smtp_port == 465
        { tls: true }
      else
        { enable_starttls: :always }
      end
    end
end
