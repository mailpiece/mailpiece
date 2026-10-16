module SupportTestHelper
  def with_support_email_address(email_address)
    previous = Rails.configuration.x.support.email_address
    Rails.configuration.x.support.email_address = email_address
    yield
  ensure
    Rails.configuration.x.support.email_address = previous
  end
end
