require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  test "address_for names the delivery on the install's domain" do
    receive_replies
    delivery = post_deliveries(:sent_to_active)

    assert_equal "replies+#{delivery.id}@reply.mailpiece.example", Reply.address_for(delivery)
    assert_equal delivery, Reply.new(Mail.new(to: Reply.address_for(delivery))).delivery
  end

  test "text is the text part, and nothing of an HTML-only reply" do
    assert_equal "Loved it.", Reply.new(Mail.new(body: "Loved it.\n")).text
    assert_equal "", Reply.new(Mail.new(body: "<p>Loved it.</p>", content_type: "text/html; charset=UTF-8")).text
  end
end
