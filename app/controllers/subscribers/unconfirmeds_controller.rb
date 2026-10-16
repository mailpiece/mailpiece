class Subscribers::UnconfirmedsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.subscribers.unconfirmed.reverse_chronologically
  end
end
