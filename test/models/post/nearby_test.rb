require "test_helper"

class Post::NearbyTest < ActiveSupport::TestCase
  setup do
    @at = Time.zone.local(2031, 1, 22, 10)
    @post = Current.account.posts.create!(title: "Edited", scheduled_posting_at: @at - 1.day)
  end

  test "posts are ten in time order: five before the moment picked, the post at it, four after" do
    nearby = nearby_among(dated(-7..-1) + dated(1..7))

    assert_equal [ *titles(-5..-1), "Edited", *titles(1..4) ], nearby.posts.map(&:title)
    assert nearby.proposed?(@post)
    assert_not nearby.proposed?(nearby.posts.first)
  end

  test "agenda_days are the days of its posts in order, the post under the day picked and not its own" do
    same_day = Current.account.posts.create!(title: "Same day").tap { it.update_columns published_at: @at + 2.hours, dated_at: @at + 2.hours }
    nearby = nearby_among(dated(-1..1) + [ same_day ])

    assert_equal [ Date.new(2031, 1, 21), Date.new(2031, 1, 22), Date.new(2031, 1, 23) ], nearby.agenda_days
    assert_equal [ "Day -1" ], nearby.posts_on(Date.new(2031, 1, 21)).map(&:title)
    assert_equal [ "Edited", "Same day" ], nearby.posts_on(Date.new(2031, 1, 22)).map(&:title)
    assert_empty nearby.posts_on(Date.new(2031, 1, 24))
  end

  test "a side with fewer posts leaves its rows to the other" do
    assert_equal [ *titles(-2..-1), "Edited", *titles(1..7) ], nearby_among(dated(-2..-1) + dated(1..9)).posts.map(&:title)
    assert_equal [ *titles(-8..-1), "Edited", *titles(1..1) ], nearby_among(dated(-9..-1) + dated(1..1)).posts.map(&:title)
  end

  test "fewer than ten dated posts are all there, and one with no date is not" do
    undated = Current.account.posts.create!(title: "No date")

    assert_equal [ *titles(-1..-1), "Edited", *titles(1..2) ], nearby_among(dated(-1..-1) + dated(1..2) + [ undated ]).posts.map(&:title)
    assert_equal [ "Edited" ], nearby_among([]).posts.map(&:title)
  end

  test "its neighbours come with their delivery counts, so reading a mailed one's state asks nothing more" do
    posts(:sent).update_columns published_at: @at - 2.hours, dated_at: @at - 2.hours
    posts(:sent).deliveries.first.update!(sent_at: nil)
    neighbours = nearby_among(dated(-2..2) + [ posts(:sent) ]).posts - [ @post ]

    assert_no_queries do
      assert_equal %w[ scheduled published sending published scheduled ], neighbours.map(&:state)
    end
  end

  private
    def nearby_among(posts)
      Post::Nearby.new(Post.where(id: [ @post, *posts ]), @post, at: @at)
    end

    def dated(days)
      days.reject(&:zero?).map do |day|
        Current.account.posts.create!(title: "Day #{day}").tap do |post|
          post.update_columns((day.odd? ? :published_at : :scheduled_posting_at) => @at + day.days, dated_at: @at + day.days)
        end
      end
    end

    def titles(days)
      days.map { "Day #{it}" }
    end
end
