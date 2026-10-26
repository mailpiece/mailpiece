require "test_helper"
require "active_storage/service/s3_service"

class ActiveStorageStructuredEventSubscriberFilteredUrlsTest < ActiveSupport::TestCase
  test "a generated URL is emitted without its signature" do
    service = ActiveStorage::Service::S3Service.new \
      bucket: "made-up-bucket", region: "us-east-1", endpoint: "https://storage.example.com", force_path_style: true,
      access_key_id: "made-up-access-key-id", secret_access_key: "made-up-secret-access-key"
    service.name = :made_up

    events = []
    subscriber = Class.new { define_method(:emit) { |event| events << event } }.new
    Rails.event.subscribe(subscriber) { |event| event[:name] == "active_storage.service_url" }

    url = Rails.event.with_debug do
      service.url("made-up-key", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("report.pdf"), disposition: :inline, content_type: "application/pdf")
    end

    signature = Rack::Utils.parse_query(URI.parse(url).query).fetch("X-Amz-Signature")
    assert_match(/\A\h{64}\z/, signature, "the generated URL keeps its signature")

    emitted = events.sole[:payload][:url]
    assert_includes emitted, "https://storage.example.com/made-up-bucket/made-up-key?"
    assert_includes emitted, "X-Amz-Signature=[FILTERED]"
    assert_includes emitted, "X-Amz-Expires=300"
    assert_not_includes emitted, signature
  ensure
    Rails.event.unsubscribe(subscriber)
  end

  test "the structured log line holds no signature" do
    output = StringIO.new
    subscriber = JsonEventSubscriber.new(output)
    Rails.event.subscribe(subscriber) { |event| event[:name] == "active_storage.service_url" }

    Rails.event.with_debug do
      ActiveSupport::Notifications.instrument "service_url.active_storage", key: "made-up-key", service: "Made-up",
        url: "https://storage.example.com/made-up-key?X-Amz-Signature=made-up-signature#page=2"
    end

    assert_equal "https://storage.example.com/made-up-key?X-Amz-Signature=[FILTERED]#page=2",
      JSON.parse(output.string.lines.sole).dig("payload", "url")
    assert_not_includes output.string, "made-up-signature"
  ensure
    Rails.event.unsubscribe(subscriber)
  end
end
