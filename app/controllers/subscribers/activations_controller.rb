class Subscribers::ActivationsController < ApplicationController
  before_action :ensure_admin
  before_action :set_subscriber
  before_action :ensure_deactivatable, only: :destroy

  def create
    @subscriber.activate

    respond_to do |format|
      format.html { redirect_to subscriber_path(@subscriber), notice: t("subscribers_activation_resumed", email: @subscriber.email) }
      format.json { render partial: "subscribers/subscriber", locals: { subscriber: @subscriber }, status: (@subscriber.saved_change_to_deactivated_at? ? :created : :ok) }
    end
  end

  def destroy
    @subscriber.deactivate

    respond_to do |format|
      format.html { redirect_to subscriber_path(@subscriber), notice: t("subscribers_activation_stopped", email: @subscriber.email) }
      format.json { head :no_content }
    end
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find(params[:subscriber_id])
    end

    def ensure_deactivatable
      unless @subscriber.deactivatable? || @subscriber.deactivated?
        respond_to do |format|
          format.json { render json: { error: t("subscribers_activation_refused") }, status: :forbidden }
          format.any { head :forbidden }
        end
      end
    end
end
