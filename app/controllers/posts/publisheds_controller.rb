class Posts::PublishedsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.posts.published.on_the_web.recently_published_first.preloaded
    Current.account.posts.load_delivery_progress @page.records
  end
end
