require "test_helper"

class Subscribers::BouncedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show lists the addresses that bounced" do
    earlier = accounts(:davids_account).subscribers.create!(email: "earlier@example.com", bounced_at: 1.month.ago)

    get subscribers_bounced_path

    assert_response :success
    assert_match subscribers(:bounced).email, response.body
    assert_match earlier.email, response.body
    assert_no_match subscribers(:active).email, response.body
  end

  test "show as JSON lists the same addresses" do
    get subscribers_bounced_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:bounced).id ], response.parsed_body.pluck("id")
  end

  test "show keeps its cache when an address it does not list changes" do
    get subscribers_bounced_path
    etag = response.headers["ETag"]

    subscribers(:active).touch

    get subscribers_bounced_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "show invalidates its cache when an address it lists changes" do
    get subscribers_bounced_path
    etag = response.headers["ETag"]

    subscribers(:bounced).update!(bounced_at: 1.day.ago)

    get subscribers_bounced_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end
end
