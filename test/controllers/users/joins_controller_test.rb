require "test_helper"

class Users::JoinsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    sign_in_as :leo
    get new_users_join_path
    assert_response :success
  end

  test "create" do
    user = users(:leo)
    sign_in_as user

    post users_joins_path, params: { user: { name: "Leo Updated" } }

    assert_redirected_to landing_path
    assert_equal "Leo Updated", user.reload.name
  end
end
