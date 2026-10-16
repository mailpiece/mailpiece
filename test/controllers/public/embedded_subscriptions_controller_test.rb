require "test_helper"

class Public::EmbeddedSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "create takes a post from another website" do
    with_forgery_protection do
      assert_enqueued_emails 1 do
        assert_difference -> { accounts(:davids_account).subscribers.unconfirmed.count }, +1 do
          post public_embedded_subscription_path, params: { email: "new@example.com" }, headers: { "Sec-Fetch-Site" => "cross-site" }
        end
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create records the website the form was posted from, and never a post" do
    post public_embedded_subscription_path, params: { email: "new@example.com", post_code: posts(:sent).code }, headers: { "Referer" => "https://example.com/about" }

    subscriber = accounts(:davids_account).subscribers.find_by!(email: "new@example.com")
    assert_equal "https://example.com/about", subscriber.referrer
    assert_nil subscriber.source_post_id
  end

  test "create drops an address that comes with the trap field filled" do
    assert_no_difference -> { Subscriber.count } do
      post public_embedded_subscription_path, params: { email: "new@example.com", reference: "https://spam.example" }
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops an address that comes with a stamp drawn a moment ago" do
    assert_no_difference -> { Subscriber.count } do
      post public_embedded_subscription_path, params: { email: "new@example.com", drawn_at: Subscriber::FormStamp.generate }
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops a Gmail address scattered with dots and answers the same" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_embedded_subscription_path, params: { email: "j.o.h.n.smith@gmail.com" }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create returns to the account's address, never to one in the request" do
    accounts(:davids_account).update!(subscription_return_url: "https://newsletter.example/thanks")

    post public_embedded_subscription_path,
      params: { email: "new@example.com", subscription_return_url: "https://elsewhere.example", return_to: "https://elsewhere.example" }

    assert_redirected_to "https://newsletter.example/thanks"
  end

  test "create returns to the same address when the trap field is filled" do
    accounts(:davids_account).update!(subscription_return_url: "https://newsletter.example/thanks")

    post public_embedded_subscription_path, params: { email: "new@example.com", reference: "x" }

    assert_redirected_to "https://newsletter.example/thanks"
  end

  test "create while the account cannot send adds nobody and returns to our own page" do
    accounts(:davids_account).update!(subscription_return_url: "https://newsletter.example/thanks")
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_embedded_subscription_path, params: { email: "new@example.com" }
      end
    end

    assert_redirected_to public_subscription_path
  end

  private
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
