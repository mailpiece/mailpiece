require "test_helper"

class Posts::NearbiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "the posts nearest the moment picked stand beside the post at that moment" do
    posts(:scheduled).update_columns scheduled_posting_at: Time.zone.local(2031, 1, 14, 9), dated_at: Time.zone.local(2031, 1, 14, 9)
    posts(:sent).update_columns published_at: Time.zone.local(2031, 1, 22, 8), dated_at: Time.zone.local(2031, 1, 22, 8)
    posts(:unlisted).update_columns published_at: Time.zone.local(2031, 2, 3, 15), dated_at: Time.zone.local(2031, 2, 3, 15)

    get post_nearby_path(posts(:scheduled), day: "2031-01-22", hour: "10"), headers: { "Turbo-Frame" => "post-nearby" }

    assert_response :success
    assert_select ".calendar__title", text: "Three deadlines in March"
    assert_select ".calendar__title", text: "Notes for the March workshop"
    assert_select ".calendar__entry--proposed .calendar__title", text: "What an inspector checks at the gate"
    assert_select "#calendar_day_2031-01-14", count: 0
  end

  test "a day that is no date, or another account's post, is not found" do
    get post_nearby_path(posts(:scheduled), day: "soon", hour: "10")
    assert_response :not_found

    get post_nearby_path(posts(:other_accounts), day: "2031-01-22", hour: "10")
    assert_response :not_found
  end
end
