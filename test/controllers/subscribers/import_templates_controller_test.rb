require "test_helper"

class Subscribers::ImportTemplatesControllerTest < ActionDispatch::IntegrationTest
  test "show sends the template to an admin" do
    sign_in_as :mia

    get subscribers_import_template_path(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match 'attachment; filename="subscribers.csv"', response.headers["Content-Disposition"]
    assert_equal "email\n", response.body
  end

  test "the template sent back as it came fills no rows" do
    sign_in_as :mia
    get subscribers_import_template_path(format: :csv)

    assert_equal [], rows_read_from(response.body)
  end

  test "the template filled in is read by its heading" do
    sign_in_as :mia
    get subscribers_import_template_path(format: :csv)

    assert_equal [ "fay@example.com" ], rows_read_from(response.body + "Fay@Example.com\n")
  end

  test "the page that reads a file links to the template" do
    sign_in_as :mia

    get new_subscribers_import_path

    assert_select "a[href='#{subscribers_import_template_path(format: :csv)}']", text: "Download a template"
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get subscribers_import_template_path(format: :csv)

    assert_response :forbidden
  end

  test "show asks for a session" do
    get subscribers_import_template_path(format: :csv)

    assert_redirected_to new_session_path(script_name: nil)
  end

  private
    def rows_read_from(content)
      post subscribers_imports_path, params: { file: Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "subscribers.csv") }
      perform_enqueued_jobs only: Subscriber::Import::ProcessJob

      accounts(:davids_account).subscriber_imports.last.tap { assert it.completed? }.rows.pluck("email")
    end
end
