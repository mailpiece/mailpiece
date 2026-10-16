require "test_helper"

class My::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "index as JSON" do
    untenanted { get my_access_tokens_path, as: :json }

    assert_response :success
    assert_equal identities(:leo).access_tokens.count, @response.parsed_body.size
    assert @response.parsed_body.none? { |access_token| access_token.key?("token") }
  end
end
