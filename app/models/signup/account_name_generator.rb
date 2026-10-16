class Signup::AccountNameGenerator
  SUFFIX = "Mailpiece".freeze

  attr_reader :identity, :name

  def initialize(identity:, name:)
    @identity = identity
    @name = name
  end

  def generate
    next_index = current_index + 1

    if next_index == 1
      I18n.t("sessions_account_name_first", name: first_name)
    else
      I18n.t("sessions_account_name_nth", name: first_name, ordinal: next_index.ordinalize, number: next_index)
    end
  end

  private
    def current_index
      existing_indices.max || 0
    end

    def existing_indices
      Current.without_account do
        identity.accounts.filter_map do |account|
          if account.name.match?(first_account_name_regex)
            1
          elsif match = account.name.match(nth_account_name_regex)
            match.captures.compact.first.to_i
          end
        end
      end
    end

    # An earlier account may have been named in the other language, so a name is read in both.
    def first_account_name_regex
      @first_account_name_regex ||= /\A(?:#{prefix}\s+#{SUFFIX}|#{SUFFIX} de #{first_name})\Z/i
    end

    def nth_account_name_regex
      @nth_account_name_regex ||= /\A(?:#{prefix}\s+(1st|2nd|3rd|\d+th)\s+#{SUFFIX}|#{SUFFIX} de #{first_name} (\d+)\Z)/i
    end

    def prefix
      @prefix ||= "#{first_name}'s"
    end

    def first_name
      name.strip.split(" ", 2).first
    end
end
