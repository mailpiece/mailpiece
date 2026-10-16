module Journey::Email::Schedulable
  extend ActiveSupport::Concern

  included do
    scope :chronologically, -> { order(:delay_days, :send_hour, :created_at, :id) }

    validates :delay_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_save :keep_time_zone, if: :will_save_change_to_send_hour?
  end

  # The day is counted from when the person entered the journey. With an hour, the email goes at that hour of
  # that day, read in the zone it was picked in, so it is the same hour all year.
  def send_time(entered_at:)
    if send_hour && journey.delayed?
      (entered_at + delay).in_time_zone(time_zone).change(hour: send_hour)
    else
      entered_at + delay
    end
  end

  private
    def delay
      if journey.delayed?
        delay_days.days
      else
        0.days
      end
    end

    # The hours are offered in the zone the first one was picked in, so whoever changes the hour changes it there.
    def keep_time_zone
      if send_hour.nil?
        self.time_zone = nil
      elsif time_zone.blank?
        self.time_zone = Time.zone.name
      end
    end
end
