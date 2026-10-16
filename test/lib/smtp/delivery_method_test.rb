require "test_helper"

class Smtp::DeliveryMethodTest < ActiveSupport::TestCase
  setup do
    @mail = Mail.new(from: "Leo <leo@newsletter.example>", to: "ada@example.com", subject: "Hello", body: "Text")
    @smtp = mock("smtp")
    @smtp.stubs(:finish)
  end

  test "hands the message to the server" do
    Net::SMTP.any_instance.expects(:start).with("localhost.localdomain", "mailpiece", "secret", "plain").returns(@smtp)
    @smtp.expects(:sendmail).with { |message, from, to| message.include?("Subject: Hello") && from == "leo@newsletter.example" && to == [ "ada@example.com" ] }

    deliver @mail
  end

  test "what a mailer notes for the relay stays out of the message" do
    @mail["Idempotency-Key"] = "delivery-1"
    @mail["X-Tags"] = "issue"
    @mail["List-Unsubscribe"] = "<https://example.com/unsubscribe>"
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.expects(:sendmail).with { |message, *| @message = message }

    deliver @mail

    assert_no_match(/Idempotency-Key|X-Tags|delivery-1/, @message)
    assert_includes @message, "List-Unsubscribe: <https://example.com/unsubscribe>"
  end

  test "a busy server is throttled" do
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.stubs(:sendmail).raises(Net::SMTPServerBusy, "451 4.3.2 Try again later")

    assert_raises(MailDelivery::Throttled) { deliver @mail }
  end

  test "a recipient or a message turned down is refused" do
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.stubs(:sendmail).raises(Net::SMTPFatalError, "550 5.1.1 No such user")

    error = assert_raises(MailDelivery::Refused) { deliver @mail }
    assert_includes error.message, "No such user"
  end

  test "an address the server cannot parse is refused" do
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.stubs(:sendmail).raises(Net::SMTPSyntaxError, "501 5.1.3 Bad recipient address syntax")

    assert_raises(MailDelivery::Refused) { deliver @mail }
  end

  test "an address that cannot be written is refused before any session opens" do
    Net::SMTP.any_instance.expects(:start).never

    [ Mail.new(from: "leo@newsletter.example", subject: "Hello", body: "Text"),
      Mail.new(to: "ada@example.com", subject: "Hello", body: "Text") ].each do |mail|
      error = assert_raises(MailDelivery::Refused) { deliver mail }
      assert_includes error.message, "may not be blank"
    end
  end

  test "an argument error from anywhere but the envelope is a bug, and no refusal" do
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.stubs(:sendmail).raises(ArgumentError, "wrong number of arguments (given 4, expected 3)")

    assert_raises(ArgumentError) { deliver @mail }

    Net::SMTP.any_instance.stubs(:start).raises(ArgumentError, "SMTPS and STARTTLS is exclusive")

    assert_raises(ArgumentError) { deliver @mail }
  end

  test "a server that turns the connection away has refused no message" do
    Net::SMTP.any_instance.stubs(:start).raises(Net::SMTPFatalError, "554 5.7.1 No service for this host")

    error = assert_raises(MailDelivery::Unavailable) { deliver @mail }
    assert_not_kind_of MailDelivery::Unauthorized, error
  end

  test "a sign-in turned down is unauthorized" do
    Net::SMTP.any_instance.stubs(:start).raises(Net::SMTPAuthenticationError, "535 5.7.8 Bad credentials")

    assert_raises(MailDelivery::Unauthorized) { deliver @mail }
  end

  test "a server out of reach, too slow or not making sense is unavailable" do
    [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError, EOFError,
      Net::SMTPSyntaxError.new("502 Not implemented"), Net::SMTPUnknownError.new("299 ?"), Net::SMTPUnsupportedCommand.new("STARTTLS is not supported") ].each do |failure|
      Net::SMTP.any_instance.stubs(:start).raises(failure)

      error = assert_raises(MailDelivery::Unavailable) { deliver @mail }
      assert_not_kind_of MailDelivery::Unauthorized, error
    end
  end

  test "a message handed over and never answered is unverified, not unavailable" do
    [ Net::ReadTimeout, Errno::ECONNRESET, Errno::EPIPE, EOFError, OpenSSL::SSL::SSLError ].each do |failure|
      Net::SMTP.any_instance.stubs(:start).returns(@smtp)
      @smtp.stubs(:sendmail).raises(failure)

      error = assert_raises(MailDelivery::Unverified) { deliver @mail }
      assert_not_kind_of MailDelivery::Unavailable, error
    end
  end

  test "it stays unverified when the goodbye fails too" do
    Net::SMTP.any_instance.stubs(:start).returns(@smtp)
    @smtp.stubs(:sendmail).raises(Net::ReadTimeout)
    @smtp.stubs(:finish).raises(EOFError)

    assert_raises(MailDelivery::Unverified) { deliver @mail }
  end

  test "a goodbye that fails once the server took the message is no failure" do
    [ EOFError, Net::ReadTimeout, Net::SMTPServerBusy.new("421 4.3.2 Closing") ].each do |failure|
      Net::SMTP.any_instance.stubs(:start).returns(@smtp)
      @smtp.stubs(:sendmail).returns(true)
      @smtp.stubs(:finish).raises(failure)

      assert_nothing_raised { deliver @mail }
    end
  end

  test "waits longer for an answer than the mail gem would" do
    method = Smtp::DeliveryMethod.new(address: "smtp.example", read_timeout: 30)

    assert_equal Smtp::DeliveryMethod::OPEN_TIMEOUT, method.settings[:open_timeout]
    assert_equal 30, method.settings[:read_timeout]
  end

  private
    def deliver(mail, **settings)
      Smtp::DeliveryMethod.new(address: "smtp.example", port: 587, user_name: "mailpiece", password: "secret", authentication: "plain", **settings).deliver!(mail)
    end
end
