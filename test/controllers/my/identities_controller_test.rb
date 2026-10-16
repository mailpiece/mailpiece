require "test_helper"

class My::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :nonstaff
    @identity = identities(:nonstaff)
  end

  test "show as JSON" do
    untenanted { get my_identity_path, as: :json }

    assert_response :success
    assert_equal @identity.id, @response.parsed_body["id"]
    assert_equal [ accounts(:davids_account).id ], account_ids
    assert_equal users(:nonstaff).id, @response.parsed_body.dig("accounts", 0, "user", "id")
    assert_equal "member", @response.parsed_body.dig("accounts", 0, "user", "role")
  end

  test "show as JSON names an account by its number, with a handle or without" do
    account = accounts(:davids_account)
    number = "/#{AccountSlug.encode(account.external_account_id)}"

    untenanted { get my_identity_path, as: :json }
    assert_equal number, @response.parsed_body.dig("accounts", 0, "slug")

    account.update!(handle: "davids-news")

    untenanted { get my_identity_path, as: :json }
    assert_equal number, @response.parsed_body.dig("accounts", 0, "slug")
  end

  test "show as JSON lists every account the identity has a user on, and no other" do
    @identity.users.create!(account: accounts(:other_account), name: "Non Staff", role: :member)

    untenanted { get my_identity_path, as: :json }

    assert_equal [ accounts(:davids_account).id, accounts(:other_account).id ].sort, account_ids.sort

    sign_in_as :mia
    untenanted { get my_identity_path, as: :json }

    assert_equal [ accounts(:davids_account).id ], account_ids
  end

  test "show as JSON leaves out a cancelled account" do
    user = @identity.users.create!(account: accounts(:other_account), name: "Non Staff", role: :owner)
    accounts(:other_account).create_cancellation!(initiated_by: user)

    untenanted { get my_identity_path, as: :json }

    assert_response :success
    assert_equal [ accounts(:davids_account).id ], account_ids
  end

  test "show inside an account is sent out of it" do
    get my_identity_path, as: :json

    assert_response :redirect
  end

  private
    def account_ids
      @response.parsed_body["accounts"].map { |account| account["id"] }
    end
end
