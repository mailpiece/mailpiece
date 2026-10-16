require "test_helper"

class Post::CalendarTest < ActiveSupport::TestCase
  setup do
    @posts = Post.where(id: [ posts(:scheduled), posts(:unlisted) ])

    posts(:scheduled).update_columns scheduled_posting_at: Time.zone.local(2026, 10, 20, 9), dated_at: Time.zone.local(2026, 10, 20, 9)
    posts(:unlisted).update_columns published_at: Time.zone.local(2026, 10, 22, 15), dated_at: Time.zone.local(2026, 10, 22, 15)
  end

  test "agenda_days are the window's days with a post, and today" do
    travel_to Time.zone.local(2026, 10, 14, 12) do
      assert_equal [ Date.new(2026, 10, 14), Date.new(2026, 10, 20), Date.new(2026, 10, 22) ],
        Post::Calendar.new(@posts, from: Date.new(2026, 10, 14)).agenda_days
      assert_equal [ Date.new(2026, 10, 20), Date.new(2026, 10, 22) ],
        Post::Calendar.new(@posts, from: Date.new(2026, 10, 18)).agenda_days
    end
  end
end
