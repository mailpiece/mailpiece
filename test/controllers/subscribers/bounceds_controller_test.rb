require "test_helper"

class Subscribers::BouncedsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the addresses that bounced, the last to bounce first" do
    earlier = accounts(:davids_account).subscribers.create!(email: "earlier@example.com", bounced_at: 1.month.ago)

    get subscribers_bounced_path

    assert_select ".breadcrumbs strong", text: "Bounced"
    assert_equal [ dom_id(subscribers(:bounced)), dom_id(earlier) ], css_select("li.row[id^=subscriber_]").map { it["id"] }
    assert_select "li##{dom_id(subscribers(:bounced))} .row__meta", text: /\ABounced/ do
      assert_select "time[datetime='#{subscribers(:bounced).bounced_at.to_i}']"
    end
  end

  test "show as JSON lists the same addresses" do
    get subscribers_bounced_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:bounced).id ], response.parsed_body.pluck("id")
  end
end
