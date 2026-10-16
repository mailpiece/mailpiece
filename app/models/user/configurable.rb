module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy

    after_create :create_settings, unless: :system?

    delegate :timezone, to: :settings, allow_nil: true
  end

  def in_time_zone(&block)
    Time.use_zone(timezone, &block)
  end
end
