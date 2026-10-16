class Subscribers::BouncesController < ApplicationController
  before_action :ensure_admin
  before_action :set_subscriber

  def create
    @subscriber.bounce

    respond_to do |format|
      format.html { redirect_to subscriber_path(@subscriber), notice: t("subscribers_bounce_marked", email: @subscriber.email) }
      format.json { head :no_content }
    end
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find(params[:subscriber_id])
    end
end
