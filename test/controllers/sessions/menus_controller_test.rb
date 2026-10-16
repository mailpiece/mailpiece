require "test_helper"

class Sessions::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:leo)
  end

  test "show redirects with one account" do
    sign_in_as :leo

    untenanted { get session_menu_path }

    assert_redirected_to root_url(script_name: accounts(:davids_account).slug)
  end

  test "show with multiple accounts" do
    Account.create_with_owner(account: { name: "Acme" }, owner: { name: "Leo", identity: @identity })
    sign_in_as :leo

    untenanted { get session_menu_path }

    assert_response :success
  end

  test "show excludes cancelled account" do
    other = Account.create_with_owner(account: { name: "Acme" }, owner: { name: "Leo", identity: @identity })
    other.cancel(initiated_by: other.users.owner.sole)
    sign_in_as :leo

    untenanted { get session_menu_path }

    assert_redirected_to root_url(script_name: accounts(:davids_account).slug)
  end

  test "show with no accounts" do
    sign_in_as :nonstaff
    users(:nonstaff).deactivate

    untenanted { get session_menu_path }

    assert_response :success
  end
end
