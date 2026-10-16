class Subscribers::ImportsController < ApplicationController
  include SubscriberImportScoped

  before_action :ensure_admin
  before_action :set_import, only: :show

  def new
  end

  def create
    @import = imports.new(file: params[:file])

    if @import.save
      @import.process_later
      redirect_to subscribers_import_path(@import)
    else
      redirect_to new_subscribers_import_path, alert: @import.errors.full_messages.to_sentence
    end
  end

  def show
    redirect_to new_subscribers_import_batch_path(@import) if @import.completed?
  end

  private
    def set_import
      @import = imports.find(params[:id])
    end
end
