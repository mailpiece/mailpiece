class Subscribers::ImportTemplatesController < ApplicationController
  before_action :ensure_admin

  def show
    send_data Subscriber::Import::TEMPLATE, filename: "subscribers.csv", type: :csv
  end
end
