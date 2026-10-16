require "test_helper"

class Subscribers::BatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "new" do
    get new_subscribers_batch_path
    assert_response :success
    assert_select "form[action=?] input[type=hidden][name='batch[sent]']", subscribers_batch_path
    assert_select "input[type=file]", count: 0
    assert_select "a[href=?]", new_subscribers_import_path, text: "Import subscribers..."
  end

  test "create with every row removed asks for one on the form" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_batch_path, params: { batch: { sent: "true" } }
    end

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Fill in at least one row/
  end

  test "create adds the rows" do
    assert_difference -> { accounts(:davids_account).subscribers.active.count }, +2 do
      post subscribers_batch_path, params: { batch: { rows: { "0" => { email: "one@example.com" }, "1" => { email: "two@example.com" } } } }
    end

    assert_redirected_to subscribers_path
    assert_equal "2 subscribers added", flash[:notice]
  end

  test "create with one row goes to that subscriber" do
    post subscribers_batch_path, params: { batch: { rows: { "0" => { email: "one@example.com" } } } }

    assert_redirected_to subscriber_path(accounts(:davids_account).subscribers.find_by!(email: "one@example.com"))
  end

  test "create adds nothing when one row cannot be added" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_batch_path, params: { batch: { rows: { "0" => { email: "one@example.com" }, "1" => { email: subscribers(:bounced).email } } } }
    end

    assert_response :unprocessable_entity
    assert_select ".batch__note", text: /bounced/
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_difference -> { Subscriber.count } do
      post subscribers_batch_path, params: { batch: { rows: { "0" => { email: "one@example.com" } } } }
    end

    assert_response :forbidden
  end
end
