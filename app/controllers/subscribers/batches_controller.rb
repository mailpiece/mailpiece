class Subscribers::BatchesController < ApplicationController
  before_action :ensure_admin

  def new
    @batch = Subscriber::Batch.new(account: Current.account)
  end

  def create
    @batch = Subscriber::Batch.new(account: Current.account, rows: batch_rows)

    if @batch.save
      redirect_to_what_was_added
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # The form always sends `sent`, so one sent with every row removed is answered on the form, not with a 400.
    def batch_params
      params.expect(batch: [ :sent, rows: [ [ :added, :email ] ] ])
    end

    def batch_rows
      rows = batch_params.fetch(:rows, {})

      rows.respond_to?(:values) ? rows.values : Array(rows)
    end

    def redirect_to_what_was_added
      if subscriber = @batch.sole_subscriber
        redirect_to subscriber_path(subscriber), notice: t("subscribers_added_one", email: subscriber.email)
      else
        redirect_to subscribers_path, notice: t("subscribers_added_many", count: @batch.count)
      end
    end
end
