class Posts::ReleasesController < ApplicationController
  include PostScoped, PostReleasing

  before_action :ensure_admin
  before_action :set_release
  before_action :ensure_deliverable
  before_action :ensure_destination_offered, if: -> { @post.draft? }

  def create
    if save_post && @release.perform
      redirect_to edit_post_path(@post), @release.outcome
    else
      render_refusal
    end
  end

  private
    def set_release
      @release = Post::Release.new(@post, destination: params[:destination], day: params[:day], hour: params[:hour], shown: params[:shown])
    end

    # A published post has only its sending left, so without a sender there is nothing to do with it.
    def ensure_deliverable
      refuse t("posts_unsent_sender") if @post.published? && !@post.deliverable?
    end

    def ensure_destination_offered
      head :forbidden if @release.destination.nil?
    end
end
