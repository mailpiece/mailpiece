require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show puts a scheduled post on its day, under no crumb but home" do
    get calendar_week_path(Date.current.iso8601)

    assert_select ".breadcrumbs a", count: 1
    assert_select ".breadcrumbs a.breadcrumbs__home + .breadcrumbs__separator + strong", text: "Calendar"
    assert_select ".header__actions a[href=?]", new_post_path
    assert_select ".calendar__week", count: 6
    assert_select ".calendar__day", count: 42
    assert_select ".calendar__day[aria-current=date]", count: 1
    assert_select "#{day_of(posts(:scheduled).scheduled_posting_at)} a.calendar__entry[href=?]", edit_post_path(posts(:scheduled)) do
      assert_select ".calendar__meta time[data-reader-time-target=time]", count: 0
      assert_select ".calendar__title", text: "What an inspector checks at the gate"
      assert_select ".status", text: "Scheduled"
    end
  end

  test "show puts a released post on the day it went out, once" do
    get calendar_week_path(posts(:sent).published_at.to_date.iso8601)

    assert_select "a[href=?]", edit_post_path(posts(:sent)), count: 1
    assert_select "#{day_of(posts(:sent).published_at)} a[href=?]", edit_post_path(posts(:sent)) do
      assert_select ".status", text: "Sent"
    end
    assert_select "#{day_of(posts(:email_only).published_at)} a[href=?]", edit_post_path(posts(:email_only)), count: 1
    assert_select "#{day_of(posts(:unlisted).published_at)} a[href=?]", edit_post_path(posts(:unlisted)) do
      assert_select ".status", text: "Published"
    end
  end

  test "show leaves out a draft with no schedule and another account's posts" do
    get calendar_week_path(posts(:sent).published_at.to_date.iso8601)

    assert_select "a[href=?]", edit_post_path(posts(:draft)), count: 0
    assert_select ".calendar__title", text: "A post from another account", count: 0
  end

  test "from moves the window to the week it falls in, and Today leads back" do
    get calendar_week_path(Date.current.iso8601)

    assert_select "a[href=?]", edit_post_path(posts(:sent)), count: 0

    from = posts(:sent).published_at.to_date
    get calendar_week_path(from.iso8601)

    first_day = from.beginning_of_week(:sunday)
    assert_select ".calendar__day:first-child time[datetime=?]", first_day.iso8601
    assert_select ".header__actions a[href=?][aria-label=?]", calendar_week_path(Date.current.iso8601), "Today"
  end

  test "show holds its weeks in a frame named for the window, between the links that load the windows before and after" do
    first_day = Date.current.beginning_of_week(:sunday)
    previous_day, next_day = first_day - 6.weeks, first_day + 6.weeks

    get calendar_week_path(Date.current.iso8601)

    frame = "[data-controller=pagination][data-pagination-paginate-on-intersection-value=true] > turbo-frame#calendar-contents-#{first_day.iso8601}[target=_top]"

    assert_select "#{frame} > .calendar__week", count: 6
    assert_select "#{frame} > a.day-timeline-pagination-link[data-pagination-target=paginationLink]:first-child[href=?][data-frame=?][data-delay=?]",
      calendar_week_path(previous_day.iso8601), "calendar-contents-#{previous_day.iso8601}", "5000"
    assert_select "#{frame} > a.day-timeline-pagination-link[data-pagination-target=paginationLink]:last-child[href=?][data-frame=?]:not([data-delay])",
      calendar_week_path(next_day.iso8601), "calendar-contents-#{next_day.iso8601}"
  end

  test "show holds its windows in a frame of one name" do
    get calendar_week_path("2026-10-04"), headers: { "Turbo-Frame" => "calendar" }

    assert_response :success
    assert_select "turbo-frame#calendar[target=_top][data-controller=pagination] > turbo-frame#calendar-contents-2026-10-04" do
      assert_select "#calendar_day_2026-10-11"
    end
  end

  test "a later window answers the frame the link asked for" do
    first_day = Date.current.beginning_of_week(:sunday) + 6.weeks

    get calendar_week_path(first_day.iso8601), headers: { "Turbo-Frame" => "calendar-contents-#{first_day.iso8601}" }

    assert_response :success
    assert_select "turbo-frame#calendar-contents-#{first_day.iso8601}" do
      assert_select ".calendar__week", count: 6
      assert_select "a.day-timeline-pagination-link[data-frame=?]", "calendar-contents-#{first_day.iso8601}", count: 0
      assert_select "a.day-timeline-pagination-link[data-frame=?]", "calendar-contents-#{(first_day - 6.weeks).iso8601}"
      assert_select "a.day-timeline-pagination-link[data-frame=?]", "calendar-contents-#{(first_day + 6.weeks).iso8601}"
    end
  end

  test "the first day of a week names its month, and a first of the month names its month and year" do
    get calendar_week_path("2026-10-04")

    assert_select "#calendar_day_2026-10-04 .calendar__month", text: "October"
    assert_select "#calendar_day_2026-10-11 .calendar__month", text: "October"
    assert_select "#calendar_day_2026-10-05 .calendar__month", count: 0
    assert_select "#calendar_day_2026-11-01 .calendar__month", text: "November 2026"
    assert_select ".calendar__month", count: 6

    get calendar_week_path("2026-11-15")

    assert_select "#calendar_day_2026-11-29 .calendar__month", text: "November"
    assert_select "#calendar_day_2026-12-01 .calendar__month", text: "December 2026"
    assert_select ".calendar__month", count: 7
  end

  test "a from that is no date is not found" do
    get calendar_week_path("soon")

    assert_response :not_found
  end

  test "the agenda puts the window's posts under their days in time order, and leaves out the empty days" do
    posts(:scheduled).update_columns scheduled_posting_at: Time.zone.local(2031, 1, 21, 9), dated_at: Time.zone.local(2031, 1, 21, 9)
    posts(:sent).update_columns published_at: Time.zone.local(2031, 2, 4, 9), dated_at: Time.zone.local(2031, 2, 4, 9)
    posts(:unlisted).update_columns published_at: Time.zone.local(2031, 2, 4, 15), dated_at: Time.zone.local(2031, 2, 4, 15)

    get calendar_agenda_path("2031-01-12")

    assert_select ".calendar__week", count: 0
    assert_select ".calendar__agenda > .calendar__agenda-day", count: 2
    assert_select "li.calendar__nothing", count: 0
    assert_select "#calendar_day_2031-01-21:not([aria-current])" do
      assert_select "time.calendar__date[datetime='2031-01-21']", text: /Tue\s+21/
      assert_select ".calendar__month", text: "Jan"
      assert_select ".calendar__nothing", count: 0
      assert_select "a.calendar__entry[href=?]", edit_post_path(posts(:scheduled)) do
        assert_select ".calendar__meta time[data-reader-time-target=time]", count: 0
        assert_select ".status", text: "Scheduled"
        assert_select ".calendar__title", text: "What an inspector checks at the gate"
      end
    end
    assert_select "#calendar_day_2031-02-04" do
      assert_select ".calendar__month", text: "Feb"
      assert_select ".calendar__entry", count: 2
      assert_equal [ edit_post_path(posts(:sent)), edit_post_path(posts(:unlisted)) ], css_select("#calendar_day_2031-02-04 .calendar__entry").map { it["href"] }
    end
  end

  test "the agenda shows today with nothing on it" do
    get calendar_agenda_path(Date.current.iso8601)

    assert_select "#calendar_day_#{Date.current.iso8601}.calendar__agenda-day[aria-current=date]" do
      assert_select ".calendar__head"
      assert_select ".calendar__nothing, .calendar__entry", count: 0
    end
  end

  test "the agenda of a window with no days says so, between its first and last day" do
    get calendar_agenda_path("2031-01-05")

    assert_select "turbo-frame#calendar-contents-2031-01-05 > .calendar__agenda > li.calendar__nothing",
      text: "Nothing published or scheduled from January 5, 2031 to February 15, 2031"
    assert_select ".calendar__agenda-day", count: 0
  end

  test "the switch keeps the window and marks the view on screen" do
    get calendar_week_path("2026-10-04")

    assert_select ".header__actions a[aria-label=Agenda][href=?]:not([aria-current])", calendar_agenda_path("2026-10-04")
    assert_select ".header__actions a[aria-label=Weeks][aria-current=true][href=?]", calendar_week_path("2026-10-04")

    get calendar_agenda_path("2026-10-04")

    assert_select ".header__actions a[aria-label=Agenda][aria-current=true][href=?]", calendar_agenda_path("2026-10-04")
    assert_select ".header__actions a.calendar__weeks-button[aria-label=Weeks][href=?]:not([aria-current])", calendar_week_path("2026-10-04")
    assert_select ".header__actions a[aria-label=Today][href=?]", calendar_agenda_path(Date.current.iso8601)
  end

  test "the agenda loads the windows before and after at a press, and the weeks as they come into view" do
    get calendar_agenda_path("2026-10-04")

    assert_select "turbo-frame#calendar[data-controller=pagination][data-pagination-paginate-on-intersection-value=false] > turbo-frame#calendar-contents-2026-10-04" do
      assert_select "a.btn.calendar__more:first-child[href=?][data-frame=?][data-pagination-target=paginationLink][data-action='pagination#loadPage:prevent']:not([data-delay])",
        calendar_agenda_path("2026-08-23"), "calendar-contents-2026-08-23", text: "Earlier"
      assert_select "a.btn.calendar__more:last-child[href=?][data-frame=?][data-pagination-target=paginationLink][data-action='pagination#loadPage:prevent']",
        calendar_agenda_path("2026-11-15"), "calendar-contents-2026-11-15", text: "Later"
      assert_select "a.calendar__more + .calendar__agenda + a.calendar__more"
      assert_select ".day-timeline-pagination-link", count: 0
    end

    get calendar_week_path("2026-10-04")

    assert_select "turbo-frame#calendar[data-controller=pagination][data-pagination-paginate-on-intersection-value=true]"
    assert_select "a.day-timeline-pagination-link:not([data-action])", count: 2
    assert_select ".calendar__more", count: 0
  end

  test "the calendar is a section of the nav after Posts, current on its weeks and its agenda where Posts is not" do
    [ calendar_week_path("2026-10-04"), calendar_agenda_path("2026-10-04") ].each do |path|
      get path

      assert_select ".site-header__link[aria-current=page][aria-keyshortcuts='2'][href=?]", calendar_path, text: /Calendar/
      assert_select ".site-header__link[href=?]:not([aria-current])", posts_path
      assert_select ".site-header__link[aria-current=page]", count: 1
    end

    get posts_path

    assert_select ".site-header__link[aria-keyshortcuts='2'][href=?]:not([aria-current])", calendar_path
    assert_select ".site-header__link[aria-current=page][href=?]", posts_path
    assert_equal %w[ 1 2 3 4 ], css_select(".site-header__link").map { it["aria-keyshortcuts"] }
  end

  test "the bare address leads to the agenda of today" do
    get calendar_path

    assert_redirected_to calendar_agenda_path(Date.current.iso8601)
  end

  test "an agenda of no date is not found" do
    get calendar_agenda_path("soon")

    assert_response :not_found
  end

  private
    def day_of(time)
      "#calendar_day_#{time.to_date.iso8601}"
    end
end
