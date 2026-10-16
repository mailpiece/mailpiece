class Public::RatingsController < Public::BaseController
  before_action :set_delivery

  def new
    @choice = Post::Rating.choices.fetch(params.expect(:choice)) { raise ActiveRecord::RecordNotFound }
    no_store
  end

  def create
    @delivery.post.rate_by(@delivery.subscriber, params.expect(:choice))
    no_store

    redirect_to public_rating_path(access_token: params[:access_token])
  end

  def show
    no_store
  end

  private
    def set_delivery
      unless @delivery = Current.account.post_deliveries.find_by_token_for(:rating, params[:access_token])
        redirect_to root_path
      end
    end
end
