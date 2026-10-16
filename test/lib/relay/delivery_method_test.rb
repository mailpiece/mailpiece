require "test_helper"

class Relay::DeliveryMethodTest < ActiveSupport::TestCase
  ENDPOINT = "https://relay.example/7/messages"

  setup do
    @mail = Mail.new(from: "Leo <leo@newsletter.example>", to: "ada@example.com", subject: "Hello") do
      text_part { body "Text" }
      html_part { content_type "text/html; charset=UTF-8"; body "<p>HTML</p>" }
    end
  end

  test "posts the message as JSON to the address as given, with the relay's token" do
    @mail["List-Unsubscribe"] = "<https://example.com/unsubscribe>"
    @mail["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    @mail["X-Tags"] = "issue"
    stub = stub_request(:post, ENDPOINT)
      .with(headers: { "Authorization" => "Bearer secret", "Content-Type" => "application/json", "Accept" => "application/json" }) { |request| @payload = JSON.parse(request.body) }
      .to_return(status: 201, body: { message_id: "<abc@newsletter.example>" }.to_json)

    deliver @mail

    assert_requested stub
    assert_equal({
      "from" => "leo@newsletter.example",
      "from_name" => "Leo",
      "to" => [ "ada@example.com" ],
      "subject" => "Hello",
      "html" => "<p>HTML</p>",
      "text" => "Text",
      "list_unsubscribe" => "<https://example.com/unsubscribe>",
      "tags" => [ "issue" ]
    }, @payload)
    assert_equal "abc@newsletter.example", @mail.message_id
  end

  test "a reply to address travels with its name, and copies with their addresses" do
    @mail.reply_to = "Leo <editor@newsletter.example>"
    @mail.cc = "bea@example.com"
    @mail.bcc = "cal@example.com"
    stub_request(:post, ENDPOINT).with { |request| @payload = JSON.parse(request.body) }.to_return(status: 201, body: "{}")

    deliver @mail

    assert_equal "editor@newsletter.example", @payload["reply_to"]
    assert_equal "Leo", @payload["reply_to_name"]
    assert_equal [ "bea@example.com" ], @payload["cc"]
    assert_equal [ "cal@example.com" ], @payload["bcc"]
  end

  test "the sender's own X- headers travel, and the tags and headers the relay composes do not" do
    @mail["X-Newsletter"] = "leo"
    @mail["X-Tags"] = "issue"
    @mail["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    stub_request(:post, ENDPOINT).with { |request| @payload = JSON.parse(request.body) }.to_return(status: 201, body: "{}")

    deliver @mail

    assert_equal({ "X-Newsletter" => "leo" }, @payload["headers"])
  end

  test "a message with no tags, headers or reply to sends none of their keys" do
    stub_request(:post, ENDPOINT).with { |request| @payload = JSON.parse(request.body) }.to_return(status: 201, body: "{}")

    deliver @mail

    assert_equal %w[ from from_name html subject text to ], @payload.keys.sort
  end

  test "an inline picture travels with the cid its HTML shows, and a file with none" do
    @mail.attachments.inline["logo.png"] = { mime_type: "image/png", content: "PNG" }
    @mail.attachments["notes.pdf"] = { mime_type: "application/pdf", content: "PDF" }
    @mail.html_part.body = %(<img src="#{@mail.attachments["logo.png"].url}">)
    stub_request(:post, ENDPOINT).with { |request| @payload = JSON.parse(request.body) }.to_return(status: 201, body: "{}")

    deliver @mail

    picture, file = @payload["attachments"]
    assert_equal({ "name" => "logo.png", "content_type" => "image/png", "content" => Base64.strict_encode64("PNG") }, picture.except("cid"))
    assert_equal "<#{@payload["html"][/cid:([^"]+)/, 1]}>", picture["cid"]
    assert_equal({ "name" => "notes.pdf", "content_type" => "application/pdf", "content" => Base64.strict_encode64("PDF") }, file)
    assert_equal "Text", @payload["text"]
  end

  test "forwards the idempotency key, the same each time the message is posted" do
    @mail["Idempotency-Key"] = "delivery-1"
    stub = stub_request(:post, ENDPOINT).with(headers: { "Idempotency-Key" => "delivery-1" }).to_return(status: 201, body: "{}")

    2.times { deliver @mail }

    assert_requested stub, times: 2
  end

  test "a message with no key of its own is posted with none" do
    stub_request(:post, ENDPOINT).with { |request| @headers = request.headers }.to_return(status: 201, body: "{}")

    deliver @mail

    assert_not @headers.key?("Idempotency-Key")
  end

  test "a message taken with an answer that cannot be read is sent, with no message id" do
    [ "", "<html>Created</html>", "[]", "null" ].each do |body|
      stub_request(:post, ENDPOINT).to_return(status: 201, body: body)

      assert_nothing_raised { deliver @mail }
      assert_nil @mail.message_id
    end
  end

  test "over the limit is throttled" do
    stub_request(:post, ENDPOINT).to_return(status: 429)

    assert_raises(MailDelivery::Throttled) { deliver @mail }
  end

  test "a message turned down is refused" do
    [ 400, 413, 422 ].each do |status|
      stub_request(:post, ENDPOINT).to_return(status: status, body: { base: [ "needs a text or html" ] }.to_json)

      assert_raises(MailDelivery::Refused) { deliver @mail }
    end
  end

  test "a token turned down is unauthorized" do
    [ 401, 403 ].each do |status|
      stub_request(:post, ENDPOINT).to_return(status: status)

      assert_raises(MailDelivery::Unauthorized) { deliver @mail }
    end
  end

  test "a relay that answers 503, or cannot be reached, is unavailable" do
    stub_request(:post, ENDPOINT).to_return(status: 503)
    assert_raises(MailDelivery::Unavailable) { deliver @mail }

    Net::HTTP.any_instance.stubs(:start).raises(Errno::ECONNREFUSED)
    assert_raises(MailDelivery::Unavailable) { deliver @mail }
  end

  test "a message posted with any other answer, or none back, is unverified" do
    [ 500, 502, 504 ].each do |status|
      stub_request(:post, ENDPOINT).to_return(status: status)

      assert_raises(MailDelivery::Unverified) { deliver @mail }
    end

    stub_request(:post, ENDPOINT).to_raise(Net::ReadTimeout)
    assert_raises(MailDelivery::Unverified) { deliver @mail }

    stub_request(:post, ENDPOINT).to_raise(Errno::ECONNRESET)
    assert_raises(MailDelivery::Unverified) { deliver @mail }
  end

  test "without a token or an address nothing is posted" do
    assert_raises(MailDelivery::Unavailable) { deliver @mail, token: nil }
    assert_raises(MailDelivery::Unavailable) { Relay::DeliveryMethod.new(token: "secret").deliver!(@mail) }

    assert_not_requested :post, ENDPOINT
  end

  private
    def deliver(mail, token: "secret")
      Relay::DeliveryMethod.new(url: ENDPOINT, token: token).deliver!(mail)
    end
end
