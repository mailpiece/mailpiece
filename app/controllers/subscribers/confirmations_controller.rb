class Subscribers::ConfirmationsController < ApplicationController
  before_action :ensure_admin
  before_action :set_subscriber
  before_action :ensure_unconfirmed

  def create
    @subscriber.confirm_and_welcome

    respond_to do |format|
      format.html { redirect_to subscriber_path(@subscriber), notice: t("subscribers_confirmation_confirmed", email: @subscriber.email) }
      format.json { render partial: "subscribers/subscriber", locals: { subscriber: @subscriber }, status: :created }
    end
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find(params[:subscriber_id])
    end

    def ensure_unconfirmed
      unless @subscriber.unconfirmed?
        respond_to do |format|
          format.json { render json: { error: t("subscribers_confirmation_refused") }, status: :forbidden }
          format.any { head :forbidden }
        end
      end
    end
end
