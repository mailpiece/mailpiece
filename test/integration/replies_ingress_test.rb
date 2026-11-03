require "test_helper"

class RepliesIngressTest < ActionDispatch::IntegrationTest
  setup do
    receive_replies
    ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = "ingress_password"
    @delivery = post_deliveries(:sent_to_active)
  end

  teardown do
    ENV.delete("RAILS_INBOUND_EMAIL_PASSWORD")
  end

  test "a reply posted under the install's password is kept under the delivery's newsletter and forwarded" do
    assert_difference -> { ActionMailbox::InboundEmail.count } => 1, -> { ActiveStorage::Blob.count } => 1 do
      post_reply
      assert_response :no_content
    end

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal @delivery.account, inbound_email.account
    assert_equal @delivery.account, inbound_email.raw_email.blob.account
    assert_equal @delivery.account, inbound_email.raw_email.attachment.account

    assert_emails 2 do
      perform_enqueued_jobs
    end
    assert inbound_email.reload.delivered?
  end

  test "mail naming no delivery is answered and not kept" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count }, -> { ActiveStorage::Blob.count } do
      post_reply to: "replies+nothing@reply.mailpiece.example"
      assert_response :no_content
    end
  end

  test "the relay must know the password" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post_reply password: "wrong"
    end

    assert_response :unauthorized
  end

  private
    def post_reply(password: ENV["RAILS_INBOUND_EMAIL_PASSWORD"], to: "replies+#{@delivery.id}@reply.mailpiece.example")
      post "/rails/action_mailbox/relay/inbound_emails", params: source(to),
        headers: { "Content-Type" => "message/rfc822", "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", password) }
    end

    def source(to)
      Mail.new(from: "Ada <ada@example.com>", to: to, subject: "Re", body: "Loved it.", message_id: "<reader@mail.example>").to_s
    end
end
