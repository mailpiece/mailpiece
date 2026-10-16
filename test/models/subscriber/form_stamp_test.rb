require "test_helper"

class Subscriber::FormStampTest < ActiveSupport::TestCase
  test "a form posted within three seconds of being drawn is hasty" do
    freeze_time
    stamp = Subscriber::FormStamp.generate

    assert Subscriber::FormStamp.new(stamp).hasty?

    travel 2.seconds
    assert Subscriber::FormStamp.new(stamp).hasty?

    travel 1.second
    assert_not Subscriber::FormStamp.new(stamp).hasty?

    travel 1.day
    assert_not Subscriber::FormStamp.new(stamp).hasty?
  end

  test "a value we did not sign is hasty" do
    stamp = Subscriber::FormStamp.generate
    travel 1.minute

    assert Subscriber::FormStamp.new("#{stamp}0").hasty?
    assert Subscriber::FormStamp.new(1.hour.ago.to_f.to_s).hasty?
    assert Subscriber::FormStamp.new("not a stamp").hasty?
    assert Subscriber::FormStamp.new(Rails.application.message_verifier(:another_purpose).generate(1.hour.ago.to_f)).hasty?
    assert Subscriber::FormStamp.new(Subscriber::FormStamp.verifier.generate("yesterday")).hasty?
  end

  test "no stamp is not hasty" do
    assert_not Subscriber::FormStamp.new(nil).hasty?
    assert_not Subscriber::FormStamp.new("").hasty?
  end
end
