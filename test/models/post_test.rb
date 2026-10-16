require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "create takes the current user and starts as a draft with a code" do
    post = Current.account.posts.create!(title: "  What an inspector   checks ")

    assert_equal users(:leo), post.creator
    assert_equal "What an inspector checks", post.title
    assert_match(/\A[0-9a-f]{8}\z/, post.code)
    assert post.draft?
    assert post.listed?
  end

  test "a draft can wait for its title, kept as nothing at all" do
    post = Current.account.posts.create!(title: " ")

    assert_nil post.title
    assert_equal "post-#{post.code}", post.public_param
  end

  test "a post published without a title is called Untitled" do
    post = Current.account.posts.create!

    assert post.schedule(at: 1.day.from_now)
    assert_nil post.reload.title

    post.publish
    assert_equal "Untitled", post.reload.title

    post.update!(title: " ")
    assert_equal "Untitled", post.reload.title
  end

  test "published and drafts" do
    assert_includes Post.published, posts(:sent)
    assert_not_includes Post.published, posts(:draft)
    assert_equal [ posts(:draft), posts(:scheduled) ].to_set, Current.account.posts.drafts.to_set
  end

  test "visibility says where a post can be read" do
    assert posts(:sent).listed?
    assert posts(:sent).on_the_web?
    assert posts(:unlisted).on_the_web?
    assert_not posts(:email_only).on_the_web?

    assert_includes Post.on_the_web, posts(:unlisted)
    assert_not_includes Post.on_the_web, posts(:email_only)
    assert_not_includes Post.listed, posts(:unlisted)
  end

  test "a visibility that does not exist is refused" do
    assert_not posts(:draft).update(visibility: "secret")
  end

  test "an email-only post is scheduled only with sending" do
    posts(:draft).update! visibility: "email_only"

    assert_not posts(:draft).schedule(at: 1.day.from_now, deliver: false)
    assert posts(:draft).schedule(at: 1.day.from_now, deliver: true)
  end

  test "publish sets the date once and sends nothing" do
    freeze_time do
      assert_no_enqueued_jobs do
        posts(:draft).publish
      end

      assert_equal Time.current, posts(:draft).reload.published_at
    end

    travel 1.hour

    assert_no_changes -> { posts(:draft).reload.published_at } do
      posts(:draft).publish
    end
    assert_not posts(:draft).sent?
  end

  test "publish takes a date, once" do
    date = 2.years.ago.change(usec: 0)

    posts(:draft).publish at: date
    assert_equal date, posts(:draft).reload.published_at

    assert_no_changes -> { posts(:draft).reload.published_at } do
      posts(:draft).publish
    end
  end

  test "a day and a whole hour are written as one time, and no day is no time" do
    assert_equal "2019-03-01T07:00", Post.on_the_hour("2019-03-01", "7")
    assert_equal "2019-03-01T00:00", Post.on_the_hour("2019-03-01", nil)
    assert_nil Post.on_the_hour("", "7")
    assert_nil Post.on_the_hour(nil, 7)
  end

  test "backdate publishes a draft under a past date and sends nothing" do
    assert_no_enqueued_jobs do
      assert posts(:scheduled).backdate(at: "2019-03-01T09:30", visibility: "unlisted")
    end

    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:scheduled).reload.published_at
    assert posts(:scheduled).unlisted?
    assert_nil posts(:scheduled).scheduled_posting_at
    assert_not posts(:scheduled).sent?
  end

  test "backdate is refused a date that has not passed, or none, and a post with no page" do
    assert_not posts(:draft).backdate(at: 1.hour.from_now)
    assert_equal [ "Pick a date and time that have already passed to publish on a past date" ], posts(:draft).errors.full_messages

    assert_not posts(:draft).backdate(at: "")
    assert posts(:draft).errors.any?

    assert_not posts(:draft).backdate(at: 1.year.ago, visibility: "email_only")
    assert_equal [ "A post published on a past date is not sent by email, so pick a destination on the web only" ], posts(:draft).errors.full_messages

    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
  end

  test "backdate does nothing to a published post" do
    assert_no_changes -> { posts(:sent).reload.published_at } do
      assert_not posts(:sent).backdate(at: 1.year.ago)
    end
    assert_empty posts(:sent).errors
  end

  test "a published post's date is corrected to the past, never ahead and never to nothing" do
    assert posts(:unlisted).update(published_at: "2019-03-01T09:30")
    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:unlisted).reload.published_at

    assert_not posts(:unlisted).update(published_at: 1.hour.from_now)
    assert_equal [ "The publication date cannot be in the future" ], posts(:unlisted).errors.full_messages

    assert_not posts(:unlisted).update(published_at: "")
    assert_equal [ "A published post keeps a publication date, so it cannot be left empty" ], posts(:unlisted).errors.full_messages

    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:unlisted).reload.published_at
  end

  test "a date sent back as the editor showed it, to the hour, changes nothing" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7, 8, 9), dated_at: Time.zone.local(2024, 5, 6, 7, 8, 9)

    posts(:unlisted).published_at = "2024-05-06T07:00"
    assert_not posts(:unlisted).changed?

    posts(:unlisted).published_at = "2024-05-06T08:00"
    assert posts(:unlisted).published_at_changed?
  end

  test "a date exactly on the hour is sent back, the day and then the hour, and changes nothing" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7), dated_at: Time.zone.local(2024, 5, 6, 7)

    posts(:unlisted).assign_attributes published_day: "2024-05-06", published_hour: "7"
    assert_not posts(:unlisted).changed?
    assert posts(:unlisted).save
    assert_equal Time.zone.local(2024, 5, 6, 7), posts(:unlisted).reload.published_at
  end

  test "a date exactly on the hour is never left empty" do
    posts(:unlisted).update_columns published_at: Time.zone.local(2024, 5, 6, 7), dated_at: Time.zone.local(2024, 5, 6, 7)

    assert_not posts(:unlisted).update(published_day: "", published_hour: "7")
    assert_equal [ "A published post keeps a publication date, so it cannot be left empty" ], posts(:unlisted).errors.full_messages
    assert_equal Time.zone.local(2024, 5, 6, 7), posts(:unlisted).published_at
    assert_not posts(:unlisted).published_at_changed?
  end

  test "only a published post with a page has a date to correct" do
    assert posts(:sent).redatable?
    assert posts(:unlisted).redatable?
    assert_not posts(:email_only).redatable?
    assert_not posts(:draft).redatable?
  end

  test "unpublish makes a draft again of a post never mailed" do
    posts(:unlisted).unpublish

    assert posts(:unlisted).reload.draft?
    assert posts(:unlisted).unlisted?
    assert_not_includes Post.published, posts(:unlisted)
  end

  test "unpublish leaves an issue already mailed as sent, by email only, and is never mailed again" do
    assert_no_enqueued_jobs do
      assert_no_changes -> { [ posts(:sent).reload.published_at, posts(:sent).sent_at ] } do
        posts(:sent).unpublish
        posts(:sent).deliver
      end
    end

    assert posts(:sent).email_only?
    assert posts(:sent).published?
    assert_not_includes Post.published.on_the_web, posts(:sent)
  end

  test "unpublish does nothing to a draft or to a post with no page" do
    assert_no_changes -> { [ posts(:draft).reload.attributes, posts(:email_only).reload.attributes ] } do
      posts(:draft).unpublish
      posts(:email_only).unpublish
    end
  end

  test "an issue that went out is given a page, and nothing else is" do
    posts(:email_only).publish_on_the_web
    assert posts(:email_only).reload.listed?

    posts(:draft).update! visibility: "email_only"
    posts(:draft).publish_on_the_web
    assert posts(:draft).reload.email_only?
    assert posts(:draft).draft?
  end

  test "the summary stands for the post wherever its beginning would, squished and never longer than its limit" do
    assert_not_equal "On ladders", posts(:sent).excerpt

    posts(:sent).update! summary: "  On   ladders "
    assert_equal "On ladders", posts(:sent).summary
    assert_equal "On ladders", posts(:sent).excerpt

    posts(:sent).update! summary: " "
    assert_nil posts(:sent).summary

    posts(:sent).update! summary: "word " * 100
    assert_operator posts(:sent).summary.length, :<=, Post::SUMMARY_LENGTH
  end

  test "publish clears the schedule" do
    posts(:scheduled).publish

    assert posts(:scheduled).reload.published?
    assert_nil posts(:scheduled).scheduled_posting_at
    assert_not posts(:scheduled).scheduled_delivery?
  end

  test "dated_at follows the schedule and then the publication, and a draft with neither has none" do
    at = 1.day.from_now.change(usec: 0)

    posts(:draft).schedule at: at
    assert_equal at, posts(:draft).reload.dated_at

    posts(:draft).unschedule
    assert_nil posts(:draft).reload.dated_at

    posts(:draft).schedule at: at
    posts(:draft).publish
    assert_equal posts(:draft).reload.published_at, posts(:draft).dated_at

    posts(:draft).update! published_at: "2019-03-01T09:30"
    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:draft).reload.dated_at

    posts(:draft).unpublish
    assert_nil posts(:draft).reload.dated_at
  end

  test "the public address reads the title and ends in the code" do
    assert_equal "three-deadlines-in-march-5e417a01", posts(:sent).public_param
    assert_equal "post-5e417a01", Post.new(title: "¿?", code: "5e417a01").public_param
  end

  test "lead_image is the first picture in the text, or nothing" do
    assert_nil posts(:sent).lead_image

    posts(:sent).update! body: %(<p>Look.</p><action-text-attachment content-type="image/png" url="https://example.com/ladder.png" width="600" height="400"></action-text-attachment>)

    assert_equal "https://example.com/ladder.png", posts(:sent).lead_image.url
  end

  test "excerpt" do
    assert_equal "Three deadlines fall together in March.", posts(:sent).excerpt
  end

  test "state is read from the dates and from how far the sending got" do
    assert_equal "draft", posts(:draft).state
    assert_equal "scheduled", posts(:scheduled).state
    assert_equal "published", posts(:unlisted).state
    assert_equal "sent", posts(:sent).state

    posts(:sent).deliveries.first.update!(sent_at: nil)
    assert_equal "sending", Post.find(posts(:sent).id).state
  end
end
