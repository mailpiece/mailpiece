require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show puts a scheduled post on the calendar" do
    get calendar_week_path(Date.current.iso8601)

    assert_response :success
    assert_match edit_post_path(posts(:scheduled)), response.body
    assert_match "What an inspector checks at the gate", response.body
  end

  test "show puts the released posts on the calendar" do
    get calendar_week_path(posts(:sent).published_at.to_date.iso8601)

    assert_response :success
    assert_match "Three deadlines in March", response.body
    assert_match "For subscribers only", response.body
    assert_match "Notes for the March workshop", response.body
  end

  test "show leaves out a draft with no schedule and another account's posts" do
    get calendar_week_path(posts(:sent).published_at.to_date.iso8601)

    assert_no_match edit_post_path(posts(:draft)), response.body
    assert_no_match "How to keep a contractor file", response.body
    assert_no_match "A post from another account", response.body
  end

  test "from moves the window to the week it falls in" do
    get calendar_week_path(Date.current.iso8601)

    assert_no_match "Three deadlines in March", response.body

    get calendar_week_path(posts(:sent).published_at.to_date.iso8601)

    assert_match "Three deadlines in March", response.body
  end

  test "a from that is no date is not found" do
    get calendar_week_path("soon")

    assert_response :not_found
  end

  test "the agenda lists the window's posts" do
    posts(:scheduled).update_columns scheduled_posting_at: Time.zone.local(2031, 1, 21, 9), dated_at: Time.zone.local(2031, 1, 21, 9)
    posts(:sent).update_columns published_at: Time.zone.local(2031, 2, 4, 9), dated_at: Time.zone.local(2031, 2, 4, 9)

    get calendar_agenda_path("2031-01-12")

    assert_response :success
    assert_match edit_post_path(posts(:scheduled)), response.body
    assert_match edit_post_path(posts(:sent)), response.body
    assert_no_match "Nothing published or scheduled", response.body
  end

  test "the agenda of a window with no days says so, between its first and last day" do
    get calendar_agenda_path("2031-01-05")

    assert_response :success
    assert_match "Nothing published or scheduled from January 5, 2031 to February 15, 2031", response.body
  end

  test "the weeks and the agenda link the windows before and after" do
    get calendar_week_path("2026-10-04")

    assert_select "a[href=?]", calendar_week_path("2026-08-23")
    assert_select "a[href=?]", calendar_week_path("2026-11-15")

    get calendar_agenda_path("2026-10-04")

    assert_select "a[href=?]", calendar_agenda_path("2026-08-23"), text: "Earlier"
    assert_select "a[href=?]", calendar_agenda_path("2026-11-15"), text: "Later"
  end

  test "the bare address leads to the agenda of today" do
    get calendar_path

    assert_redirected_to calendar_agenda_path(Date.current.iso8601)
  end

  test "an agenda of no date is not found" do
    get calendar_agenda_path("soon")

    assert_response :not_found
  end
end
