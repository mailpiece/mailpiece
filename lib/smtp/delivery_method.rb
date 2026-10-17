require "net/smtp"

# SMTP as the mail gem speaks it, with its failures told apart the way the jobs expect.
class Smtp::DeliveryMethod < Mail::SMTP
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 60

  UNANSWERED = [ Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, IOError ].freeze

  # What a mailer notes for a transport that takes it apart from the message. Over SMTP it would reach the reader.
  API_HEADERS = [ MailDelivery::IDEMPOTENCY_KEY_HEADER, MailDelivery::TAGS_HEADER ].freeze

  def initialize(values)
    super({ open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }.merge(values))
  end

  def deliver!(mail)
    API_HEADERS.each { |name| mail[name] = nil }
    envelope = envelope_for(mail)

    in_session do |smtp|
      hand_over envelope, smtp
    end
  end

  private
    # The one place an address that cannot be written says so with an ArgumentError. One raised anywhere
    # else is a bug of ours or of a gem's, and is left to say so: it must not mark a delivery refused.
    def envelope_for(mail)
      Mail::SmtpEnvelope.new(mail)
    rescue ArgumentError => error
      raise MailDelivery::Refused, "The message cannot be handed to an SMTP server: #{reply_in(error)}"
    end

    def in_session
      smtp = open_session
      yield smtp
    ensure
      close smtp if smtp
    end

    # Before the session opens a 5xx is the server turning the connection away, and says nothing of the message.
    def open_session
      start_smtp_session
    rescue Net::SMTPAuthenticationError => error
      raise MailDelivery::Unauthorized, "The SMTP server turned the newsletter down: #{reply_in(error)}"
    rescue Net::SMTPServerBusy => error
      raise MailDelivery::Throttled, "The SMTP server is busy: #{reply_in(error)}"
    rescue Net::SMTPFatalError, Net::SMTPSyntaxError => error
      raise MailDelivery::Unavailable, "The SMTP server turned the connection away: #{reply_in(error)}"
    rescue Net::SMTPError, *UNANSWERED => error
      raise MailDelivery::Unavailable, "The SMTP server could not be reached: #{error.class}"
    end

    # With the message on its way, a session that ends with no reply leaves its fate unknown: the server may
    # have taken it and been slow or cut off before saying so. A command the server cannot parse is the
    # message's own fault.
    def hand_over(envelope, smtp)
      smtp.sendmail(envelope.message, envelope.from, envelope.to)
    rescue *UNANSWERED => error
      raise MailDelivery::Unverified, "The SMTP server gave no answer for a message handed to it: #{error.class}"
    rescue Net::SMTPAuthenticationError => error
      raise MailDelivery::Unauthorized, "The SMTP server turned the newsletter down: #{reply_in(error)}"
    rescue Net::SMTPServerBusy => error
      raise MailDelivery::Throttled, "The SMTP server is busy: #{reply_in(error)}"
    rescue Net::SMTPFatalError, Net::SMTPSyntaxError => error
      raise MailDelivery::Refused, "The SMTP server refused the message: #{reply_in(error)}"
    rescue Net::SMTPError => error
      raise MailDelivery::Unavailable, "The SMTP server could not be reached: #{error.class}"
    end

    def close(smtp)
      smtp.finish
    rescue Net::SMTPError, *UNANSWERED
      # The message's fate is settled by now: once the server has said it took it, a goodbye that goes wrong
      # is no failure to send, and after a failure it has nothing to add.
    end

    def reply_in(error)
      error.message.to_s.truncate(500)
    end
end
