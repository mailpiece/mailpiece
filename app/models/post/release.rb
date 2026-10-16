# What the editor's release choices hold: where a draft goes and when, as the writer answered or as the post proposes.
class Post::Release
  attr_reader :post

  def initialize(post, destination: nil, day: nil, hour: nil, shown: nil)
    @post, @destination_name = post, destination
    @day, @hour, @shown = day, hour, shown
  end

  def destination
    @destination ||= post.destination_named(@destination_name)
  end

  def proposed
    @proposed ||= post.destination
  end

  def day
    @day.presence || proposed_at.to_date.iso8601
  end

  def hour
    (@hour.presence || proposed_at.hour).to_i
  end

  # What the date was drawn as, sent back beside it, so a date left alone means right now however long the
  # editor stood open.
  def shown
    @shown.presence || Post.on_the_hour(day, hour)
  end

  # A day left empty is no date, and never the one proposed.
  def at
    Post.on_the_hour(@day, hour)
  end

  def recipients_count
    @recipients_count ||= post.account.subscribers.active.count
  end

  # False only when the post says why not. With nothing left to do there is nothing to ask again, only an outcome to tell.
  def perform
    if redated?
      post.errors.add :base, I18n.t("posts_release_date_changed")
      false
    else
      @released = post.release(to: destination)
      @released || post.errors.none?
    end
  end

  def outcome
    if @released
      { notice: released_notice }
    elsif post.sent?
      { notice: I18n.t("posts_already_sent_notice") }
    elsif post.published?
      { notice: I18n.t("posts_nothing_sent_yet") }
    else
      { alert: I18n.t("posts_nothing_sent_any_more") }
    end
  end

  private
    def proposed_at
      post.scheduled_posting_at || Time.zone.now
    end

    # A date moved goes to the schedule or to the publication, where the bar's button points once it is. One that
    # arrives here came from a button that never moved, and releasing it now would mail what was meant for another day.
    def redated?
      at.present? && at != shown
    end

    def released_notice
      if post.sent?
        I18n.t("posts_released_sending")
      else
        I18n.t("posts_released_web")
      end
    end
end
