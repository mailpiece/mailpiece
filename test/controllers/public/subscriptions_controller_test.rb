require "test_helper"

class Public::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "show" do
    get public_subscription_path
    assert_response :success
  end

  test "show says an email went out, and names its subject" do
    get public_subscription_path

    assert_match "We just sent you an email.", response.body
    assert_match "“Confirm your subscription to #{ERB::Util.html_escape(accounts(:davids_account).name)}”", response.body
  end

  test "create adds an unconfirmed subscriber and mails one confirmation" do
    assert_enqueued_emails 1 do
      assert_difference -> { accounts(:davids_account).subscribers.unconfirmed.count }, +1 do
        post public_subscription_path, params: { email: "new@example.com" }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create records the post it was sent from by its code, and never the referrer" do
    post public_subscription_path, params: { email: "new@example.com", post_code: posts(:sent).code }, headers: { "Referer" => "https://example.com/blog" }

    subscriber = accounts(:davids_account).subscribers.find_by!(email: "new@example.com")
    assert_equal posts(:sent), subscriber.source_post
    assert_nil subscriber.referrer
  end

  test "create records no post for a code that is unknown, blank or another account's" do
    [ "zzzzzzzz", "", posts(:other_accounts).code ].each.with_index do |code, index|
      post public_subscription_path, params: { email: "new#{index}@example.com", post_code: code }

      assert_nil accounts(:davids_account).subscribers.find_by!(email: "new#{index}@example.com").source_post_id
    end
  end

  test "create never writes over where an address first came from" do
    assert_no_changes -> { subscribers(:unconfirmed).reload.attributes.slice("source_post_id", "referrer") } do
      post public_subscription_path, params: { email: subscribers(:unconfirmed).email, post_code: posts(:sent).code }, headers: { "Referer" => "https://example.com/" }
    end
  end

  test "create answers the same for an address in any state, and changes none" do
    %i[ active unconfirmed unsubscribed bounced stopped ].each do |state|
      assert_no_changes -> { subscribers(state).reload.status } do
        post public_subscription_path, params: { email: subscribers(state).email }
      end

      assert_redirected_to public_subscription_path
    end
  end

  test "create answers the same for an invalid address" do
    assert_no_difference -> { Subscriber.count } do
      post public_subscription_path, params: { email: "not an address" }
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops an address that comes with the trap field filled" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_subscription_path, params: { email: "new@example.com", reference: "https://spam.example" }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops an address posted within three seconds of the form being drawn" do
    freeze_time
    stamp = Subscriber::FormStamp.generate
    travel 2.seconds

    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_subscription_path, params: { email: "new@example.com", drawn_at: stamp }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops an address posted with a stamp we did not sign" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_subscription_path, params: { email: "new@example.com", drawn_at: 1.hour.ago.to_f.to_s }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create takes an address posted three seconds after the form was drawn" do
    freeze_time
    stamp = Subscriber::FormStamp.generate
    travel 3.seconds

    assert_enqueued_emails 1 do
      assert_difference -> { accounts(:davids_account).subscribers.unconfirmed.count }, +1 do
        post public_subscription_path, params: { email: "new@example.com", drawn_at: stamp }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create drops a Gmail address scattered with dots and answers the same" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_subscription_path, params: { email: "j.o.h.n.smith@gmail.com" }
      end
    end

    assert_redirected_to public_subscription_path
  end

  test "create takes an ordinary Gmail address and a plus address" do
    assert_enqueued_emails 2 do
      post public_subscription_path, params: { email: "john.smith@gmail.com" }
      post public_subscription_path, params: { email: "john+mailpiece@gmail.com" }
    end
  end

  test "create mails a known address once" do
    assert_enqueued_emails 1 do
      2.times { post public_subscription_path, params: { email: "new@example.com" } }
    end
  end

  test "create adds nobody and mails nothing while the account cannot send, and the page says so" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        post public_subscription_path, params: { email: "new@example.com" }
      end
    end

    assert_redirected_to public_subscription_path
    follow_redirect!
    assert_match "Not taking subscriptions yet", response.body
    assert_match public_feed_path, response.body
  end

  test "create while the account cannot send answers the same for an address in any state" do
    account_senders(:davids).destroy

    %i[ active unconfirmed unsubscribed bounced stopped ].each do |state|
      assert_no_changes -> { subscribers(state).reload.attributes } do
        post public_subscription_path, params: { email: subscribers(state).email }
      end

      assert_redirected_to public_subscription_path
    end
  end

  test "create as JSON is accepted, or a conflict while the account cannot send" do
    post public_subscription_path(format: :json), params: { email: "new@example.com" }
    assert_response :accepted

    account_senders(:davids).update!(from_address: nil)

    post public_subscription_path(format: :json), params: { email: "other@example.com" }
    assert_response :conflict
  end

  test "a cancelled account is not found" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    post public_subscription_path, params: { email: "new@example.com" }

    assert_response :not_found
  end
end
