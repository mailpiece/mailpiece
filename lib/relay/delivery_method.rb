require "net/http"

# The relay, posted each message as JSON at the address it is given. What it is posted is a contract
# relays are written against: a key is never renamed or dropped. A message whose fate is unknown is posted again
# with the same Idempotency-Key, so a relay must honour it: remember each key it has taken and answer a repeat as
# already done without sending again, since a provider with no key of its own would mail the reader twice.
class Relay::DeliveryMethod
  OPEN_TIMEOUT = 5.seconds
  READ_TIMEOUT = 15.seconds

  REFUSALS = [ 400, 413, 422 ].freeze
  UNAUTHORIZED = [ 401, 403 ].freeze

  UNREACHABLE = [ Net::OpenTimeout, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET,
    SocketError, OpenSSL::SSL::SSLError, EOFError ].freeze
  UNANSWERED = [ Net::ReadTimeout, Net::WriteTimeout, Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::EPIPE, EOFError,
    OpenSSL::SSL::SSLError, IOError ].freeze

  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    response = submit(mail)

    # A proxy's 502 or 504 can come after the relay has sent, so only 429 and 503 are taken to mean nothing was.
    case response.code.to_i
    when 200..299
      mail.message_id = message_id_in(response)
    when 429
      raise MailDelivery::Throttled, "The relay is over its submission limit"
    when 503
      raise MailDelivery::Unavailable, "The relay answered 503"
    when *REFUSALS
      raise MailDelivery::Refused, "The relay refused the message (#{response.code}): #{response.body.to_s.truncate(500)}"
    when *UNAUTHORIZED
      raise MailDelivery::Unauthorized, "The relay turned the sender down (#{response.code}): #{response.body.to_s.truncate(500)}"
    else
      raise MailDelivery::Unverified, "The relay answered #{response.code} for a message posted to it"
    end
  end

  private
    def submit(mail)
      request = request_for(mail)
      connection = connect
      hand_over request, connection
    ensure
      connection.finish if connection&.started?
    end

    def request_for(mail)
      Net::HTTP::Post.new(uri, headers_for(mail)).tap { |request| request.body = payload_for(mail).to_json }
    end

    def connect
      http.tap(&:start)
    rescue *UNREACHABLE => error
      raise MailDelivery::Unavailable, "The relay could not be reached: #{error.class}"
    end

    def hand_over(request, connection)
      connection.request(request)
    rescue *UNANSWERED => error
      raise MailDelivery::Unverified, "The relay gave no answer for a message posted to it: #{error.class}"
    end

    # A 2xx has taken the message whatever its body says, so a body that cannot be read is no failure.
    def message_id_in(response)
      JSON.parse(response.body.to_s).then { |answer| answer["message_id"] if answer.is_a?(Hash) }
    rescue JSON::ParserError
      nil
    end

    def uri
      @uri ||= URI(url)
    end

    def url
      settings[:url].presence || raise(MailDelivery::Unavailable, "there is no relay address for this message")
    end

    def token
      settings[:token].presence || raise(MailDelivery::Unavailable, "there is no relay token for this message")
    end

    def http
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http.write_timeout = READ_TIMEOUT
      end
    end

    def headers_for(mail)
      {
        "Authorization" => "Bearer #{token}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        MailDelivery::IDEMPOTENCY_KEY_HEADER => mail[MailDelivery::IDEMPOTENCY_KEY_HEADER]&.value
      }.compact
    end

    # A relay may answer 400 to an empty tags array or headers object, so the payload goes out compact_blank.
    def payload_for(mail)
      {
        from: mail[:from].addresses.first,
        from_name: mail[:from].display_names.first,
        to: Array(mail.to),
        cc: Array(mail.cc),
        bcc: Array(mail.bcc),
        reply_to: mail[:reply_to]&.addresses&.first,
        reply_to_name: mail[:reply_to]&.display_names&.first,
        subject: mail.subject,
        html: html_of(mail),
        text: text_of(mail),
        list_unsubscribe: mail["List-Unsubscribe"]&.value,
        tags: mail[MailDelivery::TAGS_HEADER]&.value.to_s.split(",").map(&:strip).compact_blank,
        headers: custom_headers_of(mail)
      }.compact_blank
    end

    def html_of(mail)
      if mail.multipart?
        mail.html_part&.decoded
      elsif mail.mime_type == "text/html"
        mail.decoded
      end
    end

    def text_of(mail)
      if mail.multipart?
        mail.text_part&.decoded
      elsif mail.mime_type != "text/html"
        mail.decoded
      end
    end

    # A relay may turn the whole message down over a header it composes itself, so only the sender's own X-
    # headers travel, the tags apart.
    def custom_headers_of(mail)
      mail.header.fields
        .select { |field| field.name.start_with?("X-") && field.name != MailDelivery::TAGS_HEADER }
        .to_h { |field| [ field.name, field.value ] }
    end
end
