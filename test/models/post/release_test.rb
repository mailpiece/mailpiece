require "test_helper"

class Post::ReleaseTest < ActiveSupport::TestCase
  test "with no answers it proposes what the post does" do
    release = Post::Release.new(posts(:draft))

    assert_nil release.destination
    assert_equal "web_and_email", release.proposed.name
    assert_nil release.at
    assert_equal 1, release.recipients_count
  end

  test "a draft's date is proposed as the hour now running, and shown as that" do
    travel_to Time.zone.local(2031, 3, 1, 14, 20) do
      release = Post::Release.new(posts(:draft))

      assert_equal "2031-03-01", release.day
      assert_equal 14, release.hour
      assert_equal "2031-03-01T14:00", release.shown
    end
  end

  test "a date sent back is kept beside what it was shown as, midnight included" do
    release = Post::Release.new(posts(:draft), day: "2019-03-01", hour: "0", shown: "2031-03-01T14:00")

    assert_equal "2019-03-01", release.day
    assert_equal 0, release.hour
    assert_equal "2031-03-01T14:00", release.shown
    assert_equal "2019-03-01T00:00", release.at
  end

  test "a scheduled post proposes its own day and hour" do
    release = Post::Release.new(posts(:scheduled))

    assert_equal posts(:scheduled).scheduled_posting_at.to_date.iso8601, release.day
    assert_equal posts(:scheduled).scheduled_posting_at.hour, release.hour
    assert_nil release.at
  end

  test "a day left empty is no date, whatever the hour" do
    release = Post::Release.new(posts(:scheduled), day: "", hour: "3")

    assert_nil release.at
    assert_equal posts(:scheduled).scheduled_posting_at.to_date.iso8601, release.day
    assert_equal 3, release.hour
  end

  test "a destination sent back is kept" do
    release = Post::Release.new(posts(:scheduled), destination: "link")

    assert_equal "link", release.destination.name
  end

  test "a destination the draft is not offered is none" do
    subscribers(:active).deactivate

    assert_nil Post::Release.new(posts(:draft), destination: "email").destination
    assert_nil Post::Release.new(posts(:draft), destination: "everywhere").destination
  end

  test "perform publishes a draft right now, and says so" do
    release = Post::Release.new(posts(:draft), destination: "link")

    assert release.perform
    assert posts(:draft).reload.published?
    assert posts(:draft).unlisted?
    assert_equal({ notice: "Published on the web" }, release.outcome)
  end

  test "perform sends a draft, and says it is on its way" do
    release = Post::Release.new(posts(:draft), destination: "web_and_email")

    assert release.perform
    assert posts(:draft).reload.sent?
    assert_equal({ notice: "Sending to subscribers is on its way" }, release.outcome)
  end

  test "perform with the date left as it was shown releases right now" do
    release = Post::Release.new(posts(:draft), destination: "web_and_email", day: "2019-03-01", hour: "7", shown: "2019-03-01T07:00")

    assert release.perform
    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
    assert posts(:draft).sent?
    assert_equal({ notice: "Sending to subscribers is on its way" }, release.outcome)
  end

  test "perform with the date moved ahead of the one shown, or back, releases nothing and says why" do
    ahead = Post::Release.new(posts(:draft), destination: "web_and_email", day: 2.days.from_now.to_date.iso8601, hour: "7", shown: Time.zone.now.strftime("%Y-%m-%dT%H:00"))
    back = Post::Release.new(posts(:draft), destination: "web_and_email", day: "2019-03-01", hour: "7", shown: "2031-03-01T14:00")

    assert_no_enqueued_jobs do
      [ ahead, back ].each do |release|
        assert_not release.perform
        assert_equal [ "The date was changed, so nothing was published. Try again." ], posts(:draft).errors.full_messages
        posts(:draft).errors.clear
      end
    end

    assert posts(:draft).reload.draft?
    assert_not posts(:draft).scheduled?
  end

  test "perform with a day left empty releases right now" do
    release = Post::Release.new(posts(:draft), destination: "web", day: "", hour: "3", shown: "2031-03-01T14:00")

    assert release.perform
    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
  end

  test "perform with nothing left to do is not refused, and says what was not done" do
    sent = Post::Release.new(posts(:sent))
    assert sent.perform
    assert_equal({ notice: "This post was already sent to subscribers" }, sent.outcome)

    subscribers(:active).deactivate
    published = Post::Release.new(posts(:unlisted))
    assert published.perform
    assert_equal({ notice: "There are no confirmed subscribers yet, so nothing was sent" }, published.outcome)
    assert_not posts(:unlisted).reload.sent?
  end
end
