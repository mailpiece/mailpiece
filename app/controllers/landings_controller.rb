class LandingsController < ApplicationController
  before_action :redirect_admin_to_posts

  def show
  end

  private
    def redirect_admin_to_posts
      redirect_to posts_path if Current.user.admin?
    end
end
