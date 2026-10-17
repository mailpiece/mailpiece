require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "system_user" do
    assert_equal users(:system), accounts(:davids_account).system_user
  end

  test "system_user raises when none" do
    account = Account.create!(name: "No System User")

    assert_raises ActiveRecord::RecordNotFound do
      account.system_user
    end
  end

  test "sends_mail? needs a complete sender, with a way to send" do
    assert accounts(:davids_account).sends_mail?

    account_senders(:davids).stop_sending
    assert_not accounts(:davids_account).reload.sends_mail?

    account_senders(:davids).use_smtp_server(smtp_address: "smtp.example", smtp_port: 587)
    assert accounts(:davids_account).reload.sends_mail?

    account_senders(:davids).update!(from_address: nil)
    assert_not accounts(:davids_account).reload.sends_mail?

    assert_not Account.create!(name: "No Sender").sends_mail?
  end

  test "external_account_id auto-increments" do
    account = Account.create!(name: "Test Account")

    assert_not_nil account.external_account_id
  end

  test "external_account_id can be overridden" do
    custom_id = 999999
    sequence_value_before = Account::ExternalIdSequence.first_or_create!(value: 0).value

    account = Account.create!(name: "Custom ID Account", external_account_id: custom_id)

    assert_equal custom_id, account.external_account_id
    assert_equal sequence_value_before, Account::ExternalIdSequence.value
  end

  test "the return address for the subscribe form is https or nothing" do
    account = accounts(:davids_account)

    assert account.update(subscription_return_url: " https://newsletter.example/thanks ")
    assert_equal "https://newsletter.example/thanks", account.subscription_return_url

    assert_not account.update(subscription_return_url: "http://newsletter.example/thanks")
    assert_not account.update(subscription_return_url: "javascript:alert(1)")

    assert account.update(subscription_return_url: " ")
    assert_nil account.subscription_return_url
  end

  test "slug is the handle once there is one, and the number until then" do
    account = accounts(:davids_account)
    assert_equal "/1234567", account.slug

    account.update!(handle: "  Contractor-Notes ")
    assert_equal "contractor-notes", account.handle
    assert_equal "/contractor-notes", account.slug

    account.update!(handle: " ")
    assert_nil account.handle
    assert_equal "/1234567", account.slug
  end

  test "a handle starts with a letter, is unique, and never takes the place of a screen" do
    account = accounts(:davids_account)

    [ "1234567", "9lives", "no", "under_score", "ends-", "posts", "calendar", "session", "my", "signup", "assets" ].each do |handle|
      account.handle = handle
      assert_not account.valid?, "#{handle} should be refused"
    end

    accounts(:other_account).update!(handle: "contractor-notes")
    account.handle = "contractor-notes"
    assert_not account.valid?

    account.handle = "contractor-notes-2"
    assert account.valid?
  end

  test "a domain is kept lowercase, and is changed and cleared freely" do
    account = accounts(:davids_account)

    account.update!(domain: "  Boletin.Example ")
    assert_equal "boletin.example", account.domain

    account.update!(domain: "news.boletin.example")
    assert_equal "news.boletin.example", account.domain

    account.update!(domain: " ")
    assert_nil account.domain
  end

  test "a domain is a host name alone, is unique, and is never the app's own host" do
    account = accounts(:davids_account)

    [ "boletin", "https://boletin.example", "boletin.example/", "boletin.example:3000", "bole tin.example", "-boletin.example",
      "boletin..example", "boletin.example.", "192.168.1.1", "example.com", "EXAMPLE.com" ].each do |domain|
      account.domain = domain
      assert_not account.valid?, "#{domain} should be refused"
      assert account.errors.of_kind?(:domain, :invalid) || account.errors.of_kind?(:domain, :exclusion)
    end

    accounts(:other_account).update!(domain: "boletin.example")
    account.domain = "Boletin.example"
    assert_not account.valid?
    assert account.errors.of_kind?(:domain, :taken)

    [ "news.boletin.example", "xn--boletn-dua.example", "b.example" ].each do |domain|
      account.domain = domain
      assert account.valid?, "#{domain} should be allowed"
    end
  end

  test "a reader's pages are at the domain's root, or under the slug on the host that was asked" do
    account = accounts(:davids_account)
    assert_equal({ script_name: "/1234567" }, account.reader_url_options)

    account.update!(handle: "contractor-notes")
    assert_equal({ script_name: "/contractor-notes" }, account.reader_url_options)

    account.update!(domain: "boletin.example")
    assert_equal({ host: "boletin.example", script_name: nil }, account.reader_url_options)
  end
end
