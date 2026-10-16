class Subscribers::Imports::BatchesController < Subscribers::BatchesController
  include SubscriberImportScoped

  before_action :set_import

  def new
    @batch = Subscriber::Batch.new(account: Current.account, import: @import)
  end

  def create
    @batch = Subscriber::Batch.new(account: Current.account, import: @import, rows: batch_rows)

    if @batch.save
      redirect_to_what_was_added
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_import
      @import = imports.completed.find(params[:import_id])
    end
end
