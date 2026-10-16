require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    sign_in_as :nonstaff

    get user_path(users(:nonstaff))

    assert_response :success
    assert_select "button", text: "Sign out"
    assert_select ".row", text: /Passkeys.*None yet/m
    assert_select ".row", text: /Personal access tokens.*None yet/m
    assert_select ".row", text: /Add users/, count: 0
    assert_select ".site-header__link[aria-current=page][href=?]", user_path(users(:nonstaff)), text: /Profile/
  end

  test "show counts the tokens and offers the join link to an admin" do
    sign_in_as :leo

    get user_path(users(:leo))

    assert_response :success
    assert_select ".row", text: /Personal access tokens.*2 tokens/m
    assert_select ".row a[href=?]", account_join_code_path, text: /Add users/
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select ".site-header__link[aria-current=page][href=?]", account_settings_path, text: /Settings/
    assert_select ".site-header__link", text: /Profile/, count: 0
  end

  test "another user's profile is not found, for an admin too" do
    sign_in_as :mia

    get user_path(users(:nonstaff))

    assert_response :not_found
  end

  test "update renames oneself" do
    sign_in_as :nonstaff

    patch user_path(users(:nonstaff)), params: { user: { name: "New Name", role: "owner" } }

    assert_redirected_to user_path(users(:nonstaff))
    assert_equal "New Name", users(:nonstaff).reload.name
    assert users(:nonstaff).member?
  end

  test "show edits the name in place and has no edit screen" do
    sign_in_as :nonstaff

    get user_path(users(:nonstaff))
    assert_select "turbo-frame#user_identity form[action=?] input[name=?]", user_path(users(:nonstaff)), "user[name]"

    get "#{user_path(users(:nonstaff))}/edit"
    assert_response :not_found
  end

  test "update from the frame replaces the identity block" do
    sign_in_as :nonstaff

    patch user_path(users(:nonstaff)), params: { user: { name: "New Name" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :success
    assert_equal "New Name", users(:nonstaff).reload.name
    assert_select "turbo-stream[action=replace][target=user_identity]"
  end

  test "update with a blank name is refused" do
    sign_in_as :nonstaff

    patch user_path(users(:nonstaff)), params: { user: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal "Non Staff", users(:nonstaff).reload.name
  end

  test "update of another user is not found" do
    sign_in_as :mia

    patch user_path(users(:nonstaff)), params: { user: { name: "Renamed" } }

    assert_response :not_found
    assert_equal "Non Staff", users(:nonstaff).reload.name
  end
end
