module Subscriber::Statuses
  extend ActiveSupport::Concern

  STATES = %w[ active unconfirmed unsubscribed bounced deactivated ].freeze

  included do
    scope :active, -> { where(bounced_at: nil, deactivated_at: nil, unsubscribed_at: nil).where.not(confirmed_at: nil) }
    scope :unconfirmed, -> { where(bounced_at: nil, deactivated_at: nil, unsubscribed_at: nil, confirmed_at: nil) }
    scope :unsubscribed, -> { where(bounced_at: nil, deactivated_at: nil).where.not(unsubscribed_at: nil) }
    scope :deactivated, -> { where(bounced_at: nil).where.not(deactivated_at: nil) }
    scope :bounced, -> { where.not(bounced_at: nil) }

    scope :recently_unsubscribed_first, -> { order(unsubscribed_at: :desc, id: :desc) }
    scope :recently_bounced_first, -> { order(bounced_at: :desc, id: :desc) }
    scope :recently_deactivated_first, -> { order(deactivated_at: :desc, id: :desc) }
  end

  def status
    if bounced_at?
      :bounced
    elsif deactivated_at?
      :deactivated
    elsif unsubscribed_at?
      :unsubscribed
    elsif confirmed_at?
      :active
    else
      :unconfirmed
    end
  end

  STATES.each do |state|
    define_method("#{state}?") { status == state.to_sym }
  end

  def listed?
    persisted? && active?
  end
end
