# The time a subscription form was drawn, signed so that whoever posts the form cannot make it up.
# Only the public forms ask: a bot fills a form faster than a person can.
class Subscriber::FormStamp
  MINIMUM_FILLING_TIME = 3.seconds

  def self.generate
    verifier.generate(Time.current.to_f)
  end

  def self.verifier
    Rails.application.message_verifier(:subscription_form)
  end

  def initialize(value)
    @value = value.to_s
  end

  # No stamp at all is not hasty: a form on another website carries none.
  def hasty?
    @value.present? && !drawn_by?(MINIMUM_FILLING_TIME.ago)
  end

  private
    def drawn_by?(time)
      drawn_at.is_a?(Numeric) && drawn_at <= time.to_f
    end

    def drawn_at
      self.class.verifier.verified(@value)
    end
end
