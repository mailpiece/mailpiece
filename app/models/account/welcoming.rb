module Account::Welcoming
  extend ActiveSupport::Concern

  included do
    has_one :welcome, dependent: :destroy
  end

  def welcoming?
    welcome.present?
  end

  # The welcome is the subscribe form set large, so an account that takes no subscribers shows none.
  def welcomes_visitors?
    welcoming? && sends_mail?
  end

  def start_welcoming
    create_welcome! unless welcoming?
  end

  def stop_welcoming
    welcome&.destroy
  end
end
