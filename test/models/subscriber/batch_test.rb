require "test_helper"

class Subscriber::BatchTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = accounts(:davids_account)
  end

  test "save adds every row confirmed, with no mail" do
    batch = Subscriber::Batch.new(account: @account, rows: [ { email: "one@example.com" }, { email: "two@example.com" }, { email: "" } ])

    assert_no_enqueued_emails do
      assert_difference -> { @account.subscribers.active.count }, +2 do
        assert batch.save
      end
    end

    assert_equal 2, batch.count
  end

  test "save adds nothing when one row cannot be added, and says why on that row" do
    batch = Subscriber::Batch.new(account: @account,
      rows: [ { email: "one@example.com" }, { email: subscribers(:unsubscribed).email }, { email: "not an address" } ])

    assert_no_difference -> { Subscriber.count } do
      assert_not batch.save
    end

    good, unsubscribed, invalid = batch.rows.map(&:subscriber)
    assert_empty good.errors
    assert_match "unsubscribed", unsubscribed.errors.full_messages.to_sentence
    assert invalid.errors.of_kind?(:email, :invalid)
  end

  test "save with every row blank asks for one" do
    batch = Subscriber::Batch.new(account: @account, rows: [ { email: "" } ])

    assert_not batch.save
    assert_equal [ "Fill in at least one row" ], batch.errors.full_messages
  end

  test "an import fills the rows with what can be added and sets the rest aside" do
    batch = Subscriber::Batch.new(account: @account, import: subscriber_imports(:read))

    assert_equal [ "new@example.com" ], batch.rows.map { |row| row.subscriber.email }
    assert_equal [ subscribers(:active).email, subscribers(:unsubscribed).email ], batch.already_on_the_list.pluck("email")
    assert_equal [ "not an address" ], batch.not_addresses.pluck("email")
  end

  test "save skips an unticked row and removes the import" do
    batch = Subscriber::Batch.new(account: @account, import: subscriber_imports(:read),
      rows: [ { email: "new@example.com", added: "1" }, { email: "left@example.com", added: "0" } ])

    assert_difference -> { @account.subscribers.count }, +1 do
      assert batch.save
    end

    assert_not Subscriber::Import.exists?(subscriber_imports(:read).id)
  end
end
