require "test_helper"

class Account::SendersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the one form, under Settings" do
    get edit_account_sender_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select "form[action=?]", account_sender_path, count: 1
    assert_select "input[name='account_sender[from_name]']"
    assert_select "input[name='account_sender[from_address]']"
    assert_select "input[name='account_sender[reply_to_address]']"
    assert_select "turbo-frame:not(#flash)", count: 0
  end

  test "edit asks for no credentials, whatever the install sends its mail with" do
    [ :nothing, :relay, :smtp ].each do |transport|
      send_mail_over transport

      get edit_account_sender_path

      assert_response :success
        assert_select "input[name='account_sender[from_address]']"
      assert_select "input[type=password]", count: 0
      assert_not_includes response.body, "stream_token"
    end
  end

  test "edit has the form before there is a sender" do
    account_senders(:davids).destroy

    get edit_account_sender_path

    assert_response :success
    assert_select "form[action=?]", account_sender_path, count: 1
    assert_select "input[name='account_sender[from_address]']"
  end

  test "there is no screen at the bare address" do
    get account_sender_path

    assert_response :not_found
  end

  test "show as JSON has who it writes as and how its mail leaves, and no credentials" do
    get account_sender_path(format: :json)

    assert_response :success
    assert_equal({ "from_name" => "Leo", "from_address" => "leo@newsletter.example", "reply_to_address" => nil, "transport" => "relay",
      "relay_url" => "https://relay.example/messages", "smtp_address" => nil, "smtp_port" => nil, "smtp_username" => nil }, response.parsed_body.to_h)
    assert_not_includes response.body, "stream_token"

    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587, smtp_username: "leo", smtp_password: "own_password")

    get account_sender_path(format: :json)

    assert_equal({ "transport" => "smtp", "relay_url" => nil, "smtp_address" => "smtp.example", "smtp_port" => 587, "smtp_username" => "leo" },
      response.parsed_body.to_h.slice("transport", "relay_url", "smtp_address", "smtp_port", "smtp_username"))
    assert_not_includes response.body, "own_password"
  end

  test "show as JSON before there is a sender" do
    account_senders(:davids).destroy

    get account_sender_path(format: :json)

    assert_response :success
    assert_equal({ "from_name" => nil, "from_address" => nil, "reply_to_address" => nil, "transport" => nil,
      "relay_url" => nil, "smtp_address" => nil, "smtp_port" => nil, "smtp_username" => nil }, response.parsed_body.to_h)
  end

  test "update as JSON answers with the sender" do
    patch account_sender_path, params: { from_name: "The Bulletin", reply_to_address: "Editor@Newsletter.example" }, as: :json

    assert_response :success
    assert_equal({ "from_name" => "The Bulletin", "from_address" => "leo@newsletter.example", "reply_to_address" => "editor@newsletter.example" },
      response.parsed_body.to_h.slice("from_name", "from_address", "reply_to_address"))
    assert_equal "The Bulletin", account_senders(:davids).reload.from_name
  end

  test "update takes nothing of how the mail leaves" do
    patch account_sender_path, params: { from_name: "The Bulletin", transport: "smtp", relay_url: "https://elsewhere.example", relay_token: "other_token" }, as: :json

    assert_response :success
    assert_equal "The Bulletin", account_senders(:davids).reload.from_name
    assert_equal [ "relay", "https://relay.example/messages", "stream_token" ], account_senders(:davids).attributes.values_at("transport", "relay_url", "relay_token")
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_sender_path, params: { from_address: "nope" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["from_address"].present?
    assert_equal "leo@newsletter.example", account_senders(:davids).reload.from_address
  end

  test "update goes back to Settings" do
    patch account_sender_path, params: { account_sender: { from_name: "The Bulletin", from_address: "Hello@Newsletter.example" } }

    assert_redirected_to account_settings_path
    assert_equal "Settings saved", flash[:notice]
    assert_equal "The Bulletin", account_senders(:davids).reload.from_name
    assert_equal "hello@newsletter.example", account_senders(:davids).from_address
  end

  test "update takes a reply to address and edit shows it" do
    patch account_sender_path, params: { account_sender: { reply_to_address: "Editor@Newsletter.example" } }
    assert_equal "editor@newsletter.example", account_senders(:davids).reload.reply_to_address
    assert_equal "leo@newsletter.example", account_senders(:davids).from_address

    get edit_account_sender_path
    assert_select "input[name='account_sender[reply_to_address]'][value=?]", "editor@newsletter.example"

    patch account_sender_path, params: { account_sender: { reply_to_address: "nope" } }
    assert_response :unprocessable_entity
  end

  test "update takes nothing of the account" do
    assert_no_changes -> { accounts(:davids_account).reload.attributes } do
      patch account_sender_path, params: { account_sender: { from_name: "Leo", account_id: accounts(:other_account).id, account_attributes: { name: "Leo's Account", external_account_id: 42 } } }
    end

    assert_equal accounts(:davids_account), account_senders(:davids).reload.account
  end

  test "update creates the sender of an account that has none" do
    account_senders(:davids).destroy

    assert_difference -> { Account::Sender.count }, +1 do
      patch account_sender_path, params: { account_sender: { from_name: "The Bulletin" } }
    end

    assert_equal "The Bulletin", accounts(:davids_account).reload.sender.from_name
  end

  test "update with an invalid address shows the form again" do
    patch account_sender_path, params: { account_sender: { from_address: "nope" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation"
    assert_select "form[action=?]", account_sender_path
    assert_equal "leo@newsletter.example", account_senders(:davids).reload.from_address
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get edit_account_sender_path
    assert_response :forbidden

    patch account_sender_path, params: { account_sender: { from_name: "Mine" } }
    assert_response :forbidden
    assert_equal "Leo", account_senders(:davids).reload.from_name
  end
end
