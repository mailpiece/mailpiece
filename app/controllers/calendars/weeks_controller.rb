class Calendars::WeeksController < ApplicationController
  include CalendarDated

  before_action :ensure_admin

  def show
    @calendar = Post::Calendar.new(Current.account.posts, from: date)
  end
end
