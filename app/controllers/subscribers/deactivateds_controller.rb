class Subscribers::DeactivatedsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.subscribers.deactivated.recently_deactivated_first
    fresh_when etag: [ @page.records, Current.account ]
  end
end
