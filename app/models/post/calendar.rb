class Post::Calendar
  WEEKS = 6

  attr_reader :from

  def initialize(posts, from:)
    @posts = posts
    @from = from.beginning_of_week(:sunday)
  end

  def weeks
    (from...next_from).each_slice(7).to_a
  end

  def agenda_days
    (from...next_from).select { it.today? || posts_on(it).any? }
  end

  def posts_on(day)
    posts_by_day.fetch(day, [])
  end

  def previous_from
    from - WEEKS.weeks
  end

  def next_from
    from + WEEKS.weeks
  end

  def last_day
    next_from - 1.day
  end

  private
    def posts_by_day
      @posts_by_day ||= posts_in_window.sort_by(&:dated_at).group_by { it.dated_at.in_time_zone.to_date }
    end

    def posts_in_window
      @posts.dated_within(from.in_time_zone...next_from.in_time_zone).with_delivery_progress
    end
end
