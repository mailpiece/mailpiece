require "test_helper"

class Post::AudienceTest < ActiveSupport::TestCase
  test "there are two, the web's and the email's, each found by the name its box carries" do
    assert_equal %i[ web email ], Post::Audience.all.map(&:medium)
    assert_equal %w[ web email ], Post::Audience.all.map(&:name)
    assert_same Post::Audience.all.first, Post::Audience.named("web")
    assert_same Post::Audience.all.last, Post::Audience.named("email")
    assert_nil Post::Audience.named("print")
    assert_nil Post::Audience.named(nil)
  end

  test "each has a label and the command that finds it, in the language being written, and one name in all" do
    web, email = Post::Audience.all

    assert_equal [ "Only on the web", "onlyweb" ], [ web.label, web.command ]
    assert_equal [ "Only in the email", "onlyemail" ], [ email.label, email.command ]

    I18n.with_locale(:es) do
      assert_equal [ "Solo en la web", "soloweb", "web" ], [ web.label, web.command, web.name ]
      assert_equal [ "Solo en el email", "soloemail", "email" ], [ email.label, email.command, email.name ]
    end
  end
end
