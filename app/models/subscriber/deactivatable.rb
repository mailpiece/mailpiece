module Subscriber::Deactivatable
  extend ActiveSupport::Concern

  def deactivatable?
    active? || unconfirmed?
  end

  def deactivate
    update!(deactivated_at: Time.current) unless deactivated_at?
  end

  def activate
    update!(deactivated_at: nil) if deactivated_at?
  end
end
