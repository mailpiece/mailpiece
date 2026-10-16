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
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select ".page > .panel > turbo-frame[id=?][target=_top] > .publication", dom_id(@account, :welcome) do
      assert_select "h2", text: "Welcome"
      assert_select "p", text: /Turn on the welcome to greet first-time visitors/
      assert_select ".publication__box:not(.publication__box--published) .publication__switch form"
    end
    assert_select "form[action=?][data-controller=form]", account_welcome_path do
      assert_select "input[name=_method]", count: 0
      assert_select "label.switch input.switch__input[type=checkbox][aria-label=?][data-action=?]:not([checked])", "Turn on the welcome", "change->form#submit"
    end
  end

  test "show with the welcome on" do
    accounts(:davids_account).start_welcoming

    get account_welcome_path

    assert_response :success
    assert_select "turbo-frame[id=?] > .publication", dom_id(@account, :welcome) do
      assert_select "p", text: /First-time visitors see only/
      assert_select ".publication__box--published .publication__switch form"
    end
    assert_select "form[action=?][data-controller=form]", account_welcome_path do
      assert_select "input[name=_method][value=delete]"
      assert_select "label.switch input.switch__input[type=checkbox][checked][aria-label=?]", "Turn off the welcome"
    end
  end

  test "turn on the welcome" do
    assert_changes -> { @account.reload.welcoming? }, from: false, to: true do
      post account_welcome_path, as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(@account, :welcome) do
      assert_select ".publication__box--published input[name=_method][value=delete]"
    end
    assert_turbo_stream action: :replace, target: "flash" do
      assert_select "template", text: /Saved/
    end
  end

  test "turn off the welcome" do
    @account.start_welcoming

    assert_changes -> { @account.reload.welcoming? }, from: true, to: false do
      delete account_welcome_path, as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(@account, :welcome) do
      assert_select ".publication__box:not(.publication__box--published) form"
      assert_select "input[name=_method]", count: 0
    end
    assert_turbo_stream action: :replace, target: "flash" do
      assert_select "template", text: /Saved/
    end
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
    assert_select "turbo-frame > form[action=?]", account_newsletter_path do
      assert_select "input[name=_method][value=patch]"
      assert_select "label", text: /Welcome message\s+Shown to first-time visitors/
      assert_select "lexxy-editor.input[name='account[welcome_message]']"
      assert_select "button[type=submit].btn--link", text: "Save"
    end
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
