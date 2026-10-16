class Posts::ResultsController < ApplicationController
  include PostScoped

  before_action :ensure_admin

  def show
    @links = @post.links
    @brought_subscribers_count = @post.brought_subscribers.count
    @ratings_count = @post.ratings.group(:choice).count
  end
end
