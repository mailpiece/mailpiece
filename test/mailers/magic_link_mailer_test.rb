require "test_helper"

class MagicLinkMailerTest < ActionMailer::TestCase
  test "the sign-in mail offers help only where there is an address to write to" do
    assert_no_match "Need help?", email.html_part.body.to_s

    with_support_email_address "help@example.com" do
      assert_match "Need help?", email.html_part.body.to_s
      assert_includes email.html_part.body.to_s, "mailto:help@example.com"
    end
  end

  private
    def email
      MagicLinkMailer.sign_in_instructions(identities(:leo).magic_links.create!)
    end
end
