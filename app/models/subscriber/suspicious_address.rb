# An address written to pass for a new one while reaching an inbox that may already be on the list.
# Only the public forms ask: an admin adding someone knows the person.
class Subscriber::SuspiciousAddress
  GMAIL_DOMAINS = %w[ gmail.com googlemail.com ].freeze
  GMAIL_DOTS_LIMIT = 3

  def initialize(address)
    @local_part, _, @domain = address.to_s.strip.downcase.rpartition("@")
  end

  def suspicious?
    gmail_scattered_with_dots?
  end

  private
    # Gmail delivers every placing of dots to the same inbox, so dots cost nothing to vary and three or more
    # are rare in an address someone chose. What follows a plus sign is the person's own and is not counted.
    def gmail_scattered_with_dots?
      @domain.in?(GMAIL_DOMAINS) && @local_part.partition("+").first.count(".") >= GMAIL_DOTS_LIMIT
    end
end
