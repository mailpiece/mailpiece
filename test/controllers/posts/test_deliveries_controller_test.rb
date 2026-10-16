require "test_helper"

class Posts::TestDeliveriesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :mia
  end

  test "create sends a test to the address given, and nothing else happens to the post" do
    assert_enqueued_email_with PostMailer, :test_issue, args: [ posts(:draft), "editor@example.com" ] do
      post post_test_delivery_path(posts(:draft)), params: { email_address: " editor@example.com " }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Test sent to editor@example.com", flash[:notice]
    assert posts(:draft).reload.draft?
    assert_empty posts(:draft).deliveries
  end

  test "create sends to one's own address when none is given" do
    assert_enqueued_email_with PostMailer, :test_issue, args: [ posts(:draft), "mia@example.com" ] do
      post post_test_delivery_path(posts(:draft))
    end
  end

  test "create saves what is on the editor first" do
    assert_enqueued_emails 1 do
      post post_test_delivery_path(posts(:draft)), params: { post: { title: "The file" } }
    end

    assert_equal "The file", posts(:draft).reload.title
  end

  test "create sends nothing when the save fails" do
    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft)), params: { post: { visibility: "nowhere" } }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "The test was not sent. Visibility", flash[:alert]
    assert_equal "How to keep a contractor file", posts(:draft).reload.title
  end

  test "create refuses an invalid address, and saves the editor all the same" do
    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft)), params: { post: { title: "The file" }, email_address: "not an address" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Enter a valid email address for the test", flash[:alert]
    assert_equal "The file", posts(:draft).reload.title
  end

  test "create as JSON says what is wrong with the address" do
    post post_test_delivery_path(posts(:draft), format: :json), params: { email_address: "not an address" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "Enter a valid email address for the test" ], response.parsed_body["base"]
  end

  test "create answers Turbo with the flash alone, so the open choices stay as they are" do
    assert_enqueued_emails 1 do
      post post_test_delivery_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true, destination: "web" },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :success
    assert_select "turbo-stream", count: 1
    assert_select "turbo-stream[action=replace][target=flash]"
    assert_includes response.body, "Test sent to mia@example.com"
    assert_equal "The file", posts(:draft).reload.title
  end

  test "create that sends nothing answers Turbo with a flash too, and draws no editor" do
    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft)), params: { email_address: "not an address" },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream", count: 1
    assert_select "turbo-stream[action=replace][target=flash]"
    assert_includes response.body, "Enter a valid email address for the test"
    assert_not_includes response.body, "post[title]"
  end

  test "create whose save fails answers Turbo with a flash that says why" do
    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft)), params: { post: { visibility: "nowhere" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_includes response.body, "The test was not sent. Visibility"
  end

  test "create from a draft's editor left open on a post published since changes and sends nothing" do
    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:unlisted)), params: { post: { title: "An old draft" }, auto_save: true }
    end

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_match "published since", flash[:alert]
    assert_equal "Notes for the March workshop", posts(:unlisted).reload.title
  end

  test "create without a complete sender sends nothing and says so" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft))
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "not sent", flash[:alert]
  end

  test "a post of another account is not found" do
    post post_test_delivery_path(posts(:other_accounts))
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_enqueued_emails do
      post post_test_delivery_path(posts(:draft)), params: { post: { title: "No" } }
    end

    assert_response :forbidden
    assert_not_equal "No", posts(:draft).reload.title
  end
end
