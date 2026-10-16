require "test_helper"

class Posts::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create publishes a draft and sends it" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_delivery_path(posts(:draft)), as: :json
    end

    assert_response :created
    assert posts(:draft).reload.published?
    assert posts(:draft).sent?
    assert_equal [ subscribers(:active) ], posts(:draft).deliveries.map(&:subscriber)
  end

  test "create on a post without a title calls it Untitled" do
    posts(:draft).update!(title: nil)

    post post_delivery_path(posts(:draft)), as: :json

    assert_response :created
    assert_equal "Untitled", response.parsed_body["title"]
    assert_equal "Untitled", posts(:draft).reload.title
  end

  test "create on a sent post sends nothing again" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      assert_no_changes -> { posts(:sent).reload.sent_at } do
        post post_delivery_path(posts(:sent)), as: :json
      end
    end

    assert_response :ok
    assert_not_nil response.parsed_body["sent_at"]
  end

  test "create with nobody active publishes, sends nothing and says so" do
    subscribers(:active).deactivate

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_delivery_path(posts(:draft)), as: :json
    end

    assert_response :ok
    assert_nil response.parsed_body["sent_at"]
    assert posts(:draft).reload.published?
    assert_not posts(:draft).sent?
  end

  test "create without a complete sender says so" do
    account_senders(:davids).update!(from_address: nil)

    post post_delivery_path(posts(:draft)), as: :json

    assert_response :unprocessable_entity
    assert_equal [ "Email sending is not set up" ], response.parsed_body["sender"]
    assert posts(:draft).reload.draft?
  end

  test "a post of another account is not found" do
    post post_delivery_path(posts(:other_accounts)), as: :json

    assert_response :not_found
    assert_not posts(:other_accounts).reload.sent?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_delivery_path(posts(:draft)), as: :json
    end

    assert_response :forbidden
    assert posts(:draft).reload.draft?
  end
end
