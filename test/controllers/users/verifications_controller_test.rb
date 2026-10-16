require "test_helper"

class Users::VerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :nonstaff
    @user = users(:nonstaff)
  end

  test "new renders the form that submits itself" do
    get new_users_verification_path

    assert_response :success
    assert_select "form[action=?]", users_verifications_path
  end

  test "create verifies the user and goes on to the join screen" do
    @user.update_column :verified_at, nil

    post users_verifications_path

    assert_redirected_to new_users_join_path
    assert @user.reload.verified?
  end

  test "create keeps the date of a user already verified" do
    assert_no_changes -> { @user.reload.verified_at } do
      post users_verifications_path
    end

    assert_redirected_to new_users_join_path
  end
end
