class Posts::ListingsController < ApplicationController
  include PostScoped

  before_action :ensure_admin
  before_action :ensure_on_the_web

  def create
    @post.list

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @post.unlist

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def ensure_on_the_web
      forbid t("posts_listing_not_on_the_web") unless @post.published? && @post.on_the_web?
    end
end
