require "test_helper"

class Subscribers::ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "new asks for a file and nothing else" do
    get new_subscribers_import_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", new_subscribers_batch_path, text: "Add subscribers"
    assert_select ".breadcrumbs strong", text: "Import subscribers..."
    assert_select "form[action=?] input[type=file]", subscribers_imports_path
    assert_select "input[type=email]", count: 0
  end

  test "create keeps the file and reads it in a job" do
    assert_enqueued_with job: Subscriber::Import::ProcessJob do
      assert_difference -> { accounts(:davids_account).subscriber_imports.count }, +1 do
        post subscribers_imports_path, params: { file: fixture_file_upload("subscribers.csv", "text/csv") }
      end
    end

    import = accounts(:davids_account).subscriber_imports.last
    assert_redirected_to subscribers_import_path(import)
    assert import.pending?
    assert_equal users(:mia), import.creator
  end

  test "create adds no subscriber" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_imports_path, params: { file: fixture_file_upload("subscribers.csv", "text/csv") }
      perform_enqueued_jobs only: Subscriber::Import::ProcessJob
    end

    assert_equal [ "fay@example.com", "gus@example.com" ], accounts(:davids_account).subscriber_imports.last.rows.pluck("email")
  end

  test "create refuses a file that is not a list" do
    assert_no_difference -> { Subscriber::Import.count } do
      post subscribers_imports_path, params: { file: fixture_file_upload("subscribers.csv", "image/png") }
    end

    assert_redirected_to new_subscribers_import_path
    assert_match "CSV or a text file", flash[:alert]
  end

  test "show waits while the file is read" do
    subscriber_imports(:read).update_columns(status: "processing")

    get subscribers_import_path(subscriber_imports(:read))

    assert_response :success
    assert_select "[data-controller=reload]", text: /Reading the file…/
  end

  test "show leads to the review once the file is read" do
    get subscribers_import_path(subscriber_imports(:read))

    assert_redirected_to new_subscribers_import_batch_path(subscriber_imports(:read))
  end

  test "show of a failed import offers another file" do
    subscriber_imports(:read).update_columns(status: "failed", failure_reason: "unreadable")

    get subscribers_import_path(subscriber_imports(:read))

    assert_response :success
    assert_select "p", text: /It has to be a CSV or a plain text file/
    assert_select ".panel a[href=?]", new_subscribers_import_path, text: "Import subscribers..."
    assert_select "input[type=email]", count: 0
  end

  test "another admin's import is not found" do
    sign_in_as :leo

    get subscribers_import_path(subscriber_imports(:read))

    assert_response :not_found
  end

  test "another account's import is not found" do
    get subscribers_import_path(subscriber_imports(:other_accounts))
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_difference -> { Subscriber::Import.count } do
      post subscribers_imports_path, params: { file: fixture_file_upload("subscribers.csv", "text/csv") }
    end

    assert_response :forbidden
  end
end
