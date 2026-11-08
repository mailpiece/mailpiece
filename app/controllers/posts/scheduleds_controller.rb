class Posts::ScheduledsController < ApplicationController
  before_action :ensure_admin

  def show
    set_page_and_extract_portion_from Current.account.posts.scheduled.latest_first.preloaded
  end
end
