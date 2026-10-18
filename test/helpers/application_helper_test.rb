require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "toolbar_button passes its options through to the link" do
    html = toolbar_button("Today", "/calendar", icon: "calendar", current: true, class: "calendar__today", data: { turbo_frame: "calendar" })

    assert_select Nokogiri::HTML::DocumentFragment.parse(html), "a.btn.btn--circle-mobile.calendar__today[aria-label=Today][aria-current=true][data-turbo-frame=calendar]" do
      assert_select "span.icon.icon--calendar"
      assert_select "span", text: "Today"
    end
  end
end
