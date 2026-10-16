# What a post's editor shows: the post at the moment picked for it, among the dated posts nearest that moment.
class Post::Nearby
  OTHERS = 9
  EARLIER = 5

  def initialize(posts, post, at:)
    @posts = posts
    @post = post
    @at = at
  end

  def posts
    [ *neighbours.values_at(*earlier.reverse), @post, *neighbours.values_at(*later) ]
  end

  def agenda_days
    posts_by_day.keys
  end

  def posts_on(day)
    posts_by_day.fetch(day, [])
  end

  def proposed?(post)
    post == @post
  end

  def time_of(post)
    if proposed?(post)
      @at
    else
      post.dated_at
    end
  end

  private
    # Loaded once with their counts, so a row's status asks nothing more.
    def neighbours
      @neighbours ||= @posts.where(id: nearest_earlier + nearest_later).with_delivery_progress.index_by(&:id)
    end

    # A side with fewer than its share leaves the rest to the other.
    def earlier
      nearest_earlier.first([ EARLIER, OTHERS - nearest_later.size ].max)
    end

    def later
      nearest_later.first(OTHERS - earlier.size)
    end

    def nearest_earlier
      @nearest_earlier ||= dated(...@at).latest_dated_first.limit(OTHERS).ids
    end

    def nearest_later
      @nearest_later ||= dated(@at..).earliest_dated_first.limit(OTHERS).ids
    end

    def dated(range)
      @posts.dated_within(range).where.not(id: @post)
    end

    def posts_by_day
      @posts_by_day ||= posts.group_by { time_of(it).in_time_zone.to_date }
    end
end
