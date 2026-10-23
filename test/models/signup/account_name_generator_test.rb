require "test_helper"

class Signup::AccountNameGeneratorTest < ActiveSupport::TestCase
  setup do
    @identity = Identity.create!(email_address: "newart.userbaum@example.com")
    @name = "Newart userbaum"
    @generator = Signup::AccountNameGenerator.new(identity: @identity, name: @name)
  end

  test "generate" do
    account_name = @generator.generate
    assert_equal "Newart's Mailpiece", account_name, "The 1st account doesn't have 1st in the name"

    first_account = Account.create!(name: account_name)
    Current.without_account do
      @identity.users.create!(account: first_account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 2nd Mailpiece", account_name
  end

  test "generate continues from the previous highest index" do
    account = Account.create!(name: "Newart's 12th Mailpiece")
    Current.without_account do
      @identity.users.create!(account: account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 13th Mailpiece", account_name
  end

  test "generate reads an account named in the other language" do
    account = Account.create!(name: "Mailpiece de Newart 4")
    Current.without_account do
      @identity.users.create!(account: account, name: @name)
      @identity.reload
    end

    account_name = @generator.generate
    assert_equal "Newart's 5th Mailpiece", account_name
  end

  test "generate treats regex metacharacters in the name literally" do
    account = Account.create!(name: "AB's Mailpiece")
    Current.without_account do
      @identity.users.create!(account: account, name: @name)
      @identity.reload
    end

    generator = Signup::AccountNameGenerator.new(identity: @identity, name: "A. Smith")
    assert_equal "A.'s Mailpiece", generator.generate
  end
end
