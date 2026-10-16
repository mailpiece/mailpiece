class Public::SubscriptionsController < Public::BaseController
  include SubscriptionRequesting

  def show
  end

  def create
    subscribe source_post: source_post

    respond_to do |format|
      format.html { redirect_to public_subscription_path }
      format.json { head Current.account.sends_mail? ? :accepted : :conflict }
    end
  end

  private
    def source_post
      Current.account.posts.find_by(code: params[:post_code].to_s) if params[:post_code].present?
    end
end
