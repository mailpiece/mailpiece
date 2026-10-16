require "test_helper"

class Account::AvatarsControllerTest < ActionDispatch::IntegrationTest
  test "show is not found while the account has no logo" do
    get account_avatar_path
    assert_response :not_found
  end

  test "destroy" do
    sign_in_as :leo

    delete account_avatar_path

    assert_redirected_to edit_account_newsletter_path
    assert_not accounts(:davids_account).reload.avatar.attached?
  end

  test "members cannot remove the logo" do
    sign_in_as :nonstaff

    delete account_avatar_path

    assert_response :forbidden
  end
end
