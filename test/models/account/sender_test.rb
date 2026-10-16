require "test_helper"

class Account::SenderTest < ActiveSupport::TestCase
  test "complete with a name and an address" do
    assert account_senders(:davids).complete?
    assert_equal "Leo <leo@newsletter.example>", account_senders(:davids).from
  end

  test "missing names what is blank" do
    sender = accounts(:davids_account).build_sender

    assert_not sender.complete?
    assert_equal %i[ from_name from_address ], sender.missing

    sender.from_name = "Leo"
    assert_not sender.complete?
    assert_equal %i[ from_address ], sender.missing

    sender.from_address = "leo@newsletter.example"
    assert sender.complete?
  end

  test "complete is the same whatever the install sends its mail with" do
    sender = Account::Sender.new(account: accounts(:davids_account), from_name: "Leo")

    [ :relay, :smtp, :nothing ].each do |transport|
      send_mail_over transport

      assert account_senders(:davids).complete?
      assert_equal %i[ from_address ], sender.missing
    end
  end

  test "reply_to carries the from name, and is nothing while the address is blank" do
    sender = account_senders(:davids)
    assert_nil sender.reply_to

    sender.update!(reply_to_address: " Editor@Newsletter.example ")
    assert_equal "editor@newsletter.example", sender.reply_to_address
    assert_equal "Leo <editor@newsletter.example>", sender.reply_to
    assert sender.complete?
  end

  test "a reply to address has to be an email address" do
    sender = account_senders(:davids)

    assert_not sender.update(reply_to_address: "nope")
    assert_equal [ "Reply to is invalid" ], sender.errors.full_messages
  end

  test "a sender holds no credentials" do
    assert_empty Account::Sender.column_names & %w[ sending_token webhook_secret ]
  end

  test "domain is the from address's" do
    assert_equal "newsletter.example", account_senders(:davids).domain
  end
end
