require "test_helper"

class Posts::NearbiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "the posts nearest the moment picked stand under their days as in the agenda, with the post at that moment and nothing to follow" do
    posts(:scheduled).update_columns scheduled_posting_at: Time.zone.local(2031, 1, 14, 9), dated_at: Time.zone.local(2031, 1, 14, 9)
    posts(:sent).update_columns published_at: Time.zone.local(2031, 1, 22, 8), dated_at: Time.zone.local(2031, 1, 22, 8)
    posts(:unlisted).update_columns published_at: Time.zone.local(2031, 2, 3, 15), dated_at: Time.zone.local(2031, 2, 3, 15)

    get post_nearby_path(posts(:scheduled), day: "2031-01-22", hour: "10"), headers: { "Turbo-Frame" => "post-nearby" }

    assert_response :success
    assert_select "turbo-frame#post-nearby > ol.calendar__agenda > li.calendar__agenda-day", count: 3
    assert_select "turbo-frame#post-nearby a, turbo-frame#post-nearby turbo-frame, .calendar__nothing", count: 0
    assert_select "#calendar_day_2031-01-14", count: 0
    assert_select "#calendar_day_2031-01-22:not([aria-current])" do
      assert_select ".calendar__head time.calendar__date[datetime='2031-01-22']", text: /Wed\s+22/
      assert_select ".calendar__head .calendar__month", text: "Jan"
      assert_select "div.calendar__entry", count: 2
      assert_select "div.calendar__entry:nth-of-type(2):not(.calendar__entry--proposed)" do
        assert_select ".calendar__meta .status", text: "Sent"
        assert_select "strong.calendar__title[title=?]", "Three deadlines in March", text: "Three deadlines in March"
      end
      assert_select "div.calendar__entry:nth-of-type(3).calendar__entry--proposed" do
        assert_select ".calendar__meta .calendar__this-post", text: "This post"
        assert_select "strong.calendar__title[title=?]", "What an inspector checks at the gate"
        assert_select ".status", count: 0
      end
    end
    assert_select "#calendar_day_2031-02-03 > div.calendar__entry .status", text: "Published"
    assert_select ".calendar__entry--proposed", count: 1
    assert_select ".calendar__meta time[data-reader-time-target=time]", count: 0
  end

  test "the day picked is tinted when it is today" do
    get post_nearby_path(posts(:draft), day: Date.current.iso8601, hour: "10"), headers: { "Turbo-Frame" => "post-nearby" }

    assert_select "#calendar_day_#{Date.current.iso8601}.calendar__agenda-day[aria-current=date] > .calendar__entry--proposed"
  end

  test "a day that is no date, or another account's post, is not found" do
    get post_nearby_path(posts(:scheduled), day: "soon", hour: "10")
    assert_response :not_found

    get post_nearby_path(posts(:other_accounts), day: "2031-01-22", hour: "10")
    assert_response :not_found
  end
end
