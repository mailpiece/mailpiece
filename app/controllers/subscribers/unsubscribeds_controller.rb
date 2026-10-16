class Subscribers::UnsubscribedsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.subscribers.unsubscribed.recently_unsubscribed_first
  end
end
