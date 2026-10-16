class SubscribersController < ApplicationController
  wrap_parameters :subscriber, include: %i[ email ]

  before_action :ensure_admin
  before_action :set_subscriber, only: %i[ show destroy ]

  def index
    set_page_and_extract_portion_from Current.account.subscribers.active.reverse_chronologically
    fresh_when etag: [ @page.records, Current.account.subscribers, Current.account ]
  end

  def show
    set_page_and_extract_portion_from @subscriber.deliveries.preload(:post).order(created_at: :desc, id: :desc) if request.format.json?
  end

  def create
    @subscriber = Current.account.subscribers.add(subscriber_params[:email])

    if @subscriber.listed?
      respond_to do |format|
        format.html { redirect_to subscribers_path }
        format.json { render partial: "subscribers/subscriber", locals: { subscriber: @subscriber }, status: (@subscriber.previously_new_record? ? :created : :ok) }
      end
    else
      respond_to do |format|
        format.html { redirect_to subscribers_path, alert: t("subscribers_create_refused", email: @subscriber.email.to_s.truncate(60)) }
        format.json { render json: @subscriber.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @subscriber.destroy!

    respond_to do |format|
      format.html { redirect_to subscribers_path, notice: t("subscribers_deleted", email: @subscriber.email) }
      format.json { head :no_content }
    end
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find(params[:id])
    end

    def subscriber_params
      params.expect(subscriber: [ :email ])
    end
end
