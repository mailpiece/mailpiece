require "test_helper"

class Subscribers::Imports::BatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @import = subscriber_imports(:read)
  end

  test "new fills the rows with what was read" do
    get new_subscribers_import_batch_path(@import)

    assert_response :success
    assert_select ".breadcrumbs strong", text: "Import subscribers..."
    assert_select "form[action=?]", subscribers_import_batch_path(@import)
    assert_select "input[type=email][value='new@example.com']"
    assert_select ".batch__row--registered", text: /Skipped: not an email address/
  end

  test "new is not found until the file is read" do
    @import.update_columns(status: "processing")

    get new_subscribers_import_batch_path(@import)

    assert_response :not_found
  end

  test "create adds the rows and removes the import" do
    post subscribers_import_batch_path(@import), params: { batch: { rows: { "0" => { email: "new@example.com", added: "1" } } } }

    assert_redirected_to subscriber_path(accounts(:davids_account).subscribers.find_by!(email: "new@example.com"))
    assert_not Subscriber::Import.exists?(@import.id)
  end

  test "create that fails shows the rows as they were sent" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_import_batch_path(@import), params: { batch: { rows: {
        "0" => { email: "edited@example.com", added: "0" },
        "1" => { email: subscribers(:bounced).email, added: "1" } } } }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", subscribers_import_batch_path(@import)
    assert_select "input[type=email][value='edited@example.com']"
    assert_select "input[type=checkbox][name='batch[rows][0][added]']:not([checked])"
    assert_select "input[type=checkbox][name='batch[rows][1][added]'][checked]"
    assert_select ".batch__note", text: /bounced/
    assert Subscriber::Import.exists?(@import.id)
  end

  test "create with nothing ticked asks for a row on the form" do
    post subscribers_import_batch_path(@import), params: { batch: { rows: { "0" => { email: "new@example.com", added: "0" } } } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Fill in at least one row/
    assert_select "input[type=email][value='new@example.com']"
  end

  test "another admin's import is not found" do
    sign_in_as :leo

    post subscribers_import_batch_path(@import), params: { batch: { rows: { "0" => { email: "new@example.com" } } } }

    assert_response :not_found
    assert Subscriber::Import.exists?(@import.id)
  end

  test "another account's import is not found" do
    post subscribers_import_batch_path(subscriber_imports(:other_accounts)), params: { batch: { rows: { "0" => { email: "new@example.com" } } } }

    assert_response :not_found
    assert Subscriber::Import.exists?(subscriber_imports(:other_accounts).id)
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_difference -> { Subscriber.count } do
      post subscribers_import_batch_path(@import), params: { batch: { rows: { "0" => { email: "new@example.com" } } } }
    end

    assert_response :forbidden
  end
end
