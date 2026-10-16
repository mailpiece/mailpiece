require "test_helper"

class Account::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    sign_in_as :leo
    get account_join_code_path
    assert_response :success
    assert_select "button[aria-haspopup=dialog][aria-expanded=false][data-dialog-focus-target=trigger]", text: "Get QR code"
    assert_select "dialog img.qr-code[src*=?]", "/qr_codes/"
  end

  test "destroy" do
    sign_in_as :leo

    assert_changes -> { accounts(:davids_account).join_code.reload.code } do
      delete account_join_code_path
    end

    assert_redirected_to account_join_code_path
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get account_join_code_path
    assert_response :forbidden

    assert_no_changes -> { accounts(:davids_account).join_code.reload.code } do
      delete account_join_code_path
    end
    assert_response :forbidden
  end
end
