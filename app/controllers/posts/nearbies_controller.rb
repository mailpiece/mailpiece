class Posts::NearbiesController < ApplicationController
  include PostScoped, CalendarDated

  before_action :ensure_admin

  def show
    @nearby = Post::Nearby.new(Current.account.posts, @post, at: picked_at)
  end

  private
    # Read as a schedule's day and hour are, in the zone of whoever asks.
    def picked_at
      Time.zone.parse(Post.on_the_hour(date(:day).iso8601, params[:hour]))
    end
end
