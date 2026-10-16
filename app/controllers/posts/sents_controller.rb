class Posts::SentsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.posts.sent.recently_published_first.preloaded
    Current.account.posts.load_delivery_progress @page.records
  end
end
