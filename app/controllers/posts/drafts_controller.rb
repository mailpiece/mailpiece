class Posts::DraftsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.posts.drafts.unscheduled.reverse_chronologically.preloaded
  end
end
