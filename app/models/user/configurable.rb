module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy

    after_create :create_settings, unless: :system?

    scope :notified_of, ->(setting) { admin.where.not(verified_at: nil).joins(:settings).merge(User::Settings.where(setting => true)) }

    delegate :timezone, to: :settings, allow_nil: true
  end

  def in_time_zone(&block)
    Time.use_zone(timezone, &block)
  end
end
