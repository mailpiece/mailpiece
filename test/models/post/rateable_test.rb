require "test_helper"

class Post::RateableTest < ActiveSupport::TestCase
  test "rate_by keeps one rating per subscriber, and choosing again changes it" do
    assert_difference -> { posts(:sent).ratings.count }, 1 do
      posts(:sent).rate_by(subscribers(:active), "liked")
      posts(:sent).rate_by(subscribers(:active), "disliked")
    end

    rating = posts(:sent).ratings.sole
    assert rating.disliked?
    assert_equal accounts(:davids_account), rating.account
  end

  test "rate_by refuses a choice that is neither" do
    assert_raises(ActiveRecord::RecordInvalid) { posts(:sent).rate_by(subscribers(:active), "loved it") }
  end

  test "ratings go with the post and with the subscriber" do
    posts(:sent).rate_by(subscribers(:active), "liked")
    posts(:sent).rate_by(subscribers(:unsubscribed), "disliked")

    subscribers(:active).destroy!
    assert_equal [ subscribers(:unsubscribed) ], posts(:sent).ratings.map(&:subscriber)

    posts(:sent).destroy!
    assert_empty Post::Rating.all
  end
end
