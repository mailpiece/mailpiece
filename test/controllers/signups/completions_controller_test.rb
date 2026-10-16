require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    untenanted do
      post session_path, params: { email_address: "newcomer@example.com" }
      post session_magic_link_url, params: { code: newcomer.magic_links.last.code }
    end
  end

  test "new" do
    untenanted { get new_signup_completion_path }

    assert_response :success
  end

  test "create" do
    assert_difference -> { Account.count }, +1 do
      untenanted { post signup_completion_path, params: { signup: { full_name: "New Comer" } } }
    end

    assert_response :redirect
    assert newcomer.users.sole.owner?
  end

  test "create with a blank name" do
    assert_no_difference -> { Account.count } do
      untenanted { post signup_completion_path, params: { signup: { full_name: "" } } }
    end

    assert_response :unprocessable_entity
  end

  test "create is refused once the one account exists" do
    with_multi_tenant_mode(false) do
      untenanted do
        assert_no_difference -> { Account.count } do
          post signup_completion_path, params: { signup: { full_name: "New Comer" } }
        end

        assert_redirected_to new_session_url
      end
    end
  end

  private
    def newcomer
      Identity.find_by!(email_address: "newcomer@example.com")
    end
end
