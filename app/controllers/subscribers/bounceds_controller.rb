class Subscribers::BouncedsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.subscribers.bounced.recently_bounced_first.preloaded
    fresh_when etag: [ @page.records, Current.account.subscribers, Current.account ]
  end
end
