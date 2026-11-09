require "test_helper"

class Account::WelcomesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :leo
    @account = accounts(:davids_account)
  end

  test "show with the welcome off" do
    get account_welcome_path

    assert_response :success
    assert_select "input[type=checkbox][aria-label=?]:not([checked])", "Turn on the welcome"
  end

  test "show with the welcome on" do
    accounts(:davids_account).start_welcoming

    get account_welcome_path

    assert_response :success
    assert_select "input[type=checkbox][checked][aria-label=?]", "Turn off the welcome"
  end

  test "turn on the welcome" do
    assert_changes -> { @account.reload.welcoming? }, from: false, to: true do
      post account_welcome_path, as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(@account, :welcome)
    assert_turbo_stream action: :replace, target: "flash"
  end

  test "turn off the welcome" do
    @account.start_welcoming

    assert_changes -> { @account.reload.welcoming? }, from: true, to: false do
      delete account_welcome_path, as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(@account, :welcome)
    assert_turbo_stream action: :replace, target: "flash"
  end

  test "turn the welcome on and off without Turbo" do
    post account_welcome_path
    assert_redirected_to account_welcome_path
    assert_equal "Saved", flash[:notice]
    assert @account.reload.welcoming?

    delete account_welcome_path
    assert_redirected_to account_welcome_path
    assert_not @account.reload.welcoming?
  end

  test "show the welcome message form" do
    get account_welcome_path
    assert_select "lexxy-editor[name='account[welcome_message]']", count: 0

    @account.start_welcoming

    get account_welcome_path
    assert_select "lexxy-editor[name='account[welcome_message]']"
  end

  test "show via JSON" do
    get account_welcome_path(format: :json)

    assert_response :success
    assert_equal({ "active" => false }, response.parsed_body.to_h)
  end

  test "turn on the welcome via JSON" do
    assert_changes -> { @account.reload.welcoming? }, from: false, to: true do
      post account_welcome_path, as: :json
    end

    assert_response :created
    assert_equal({ "active" => true }, response.parsed_body.to_h)
  end

  test "turn off the welcome via JSON" do
    @account.start_welcoming

    assert_changes -> { @account.reload.welcoming? }, from: true, to: false do
      delete account_welcome_path, as: :json
    end

    assert_response :no_content
  end

  test "turning on requires an admin" do
    sign_in_as :nonstaff

    post account_welcome_path

    assert_response :forbidden
    assert_not @account.reload.welcoming?
  end

  test "turning off requires an admin" do
    @account.start_welcoming
    sign_in_as :nonstaff

    delete account_welcome_path

    assert_response :forbidden
    assert @account.reload.welcoming?
  end

  test "show requires an admin" do
    sign_in_as :nonstaff

    get account_welcome_path

    assert_response :forbidden
  end
end
