class Posts::PublicationsController < ApplicationController
  include PostScoped, PostReleasing

  wrap_parameters :post, include: %i[ title summary body ]

  before_action :ensure_admin
  before_action :set_destination, :ensure_destination_offered, :ensure_publishable, only: :create

  def create
    if save_post && @post.publish_to(@destination, at: published_at)
      respond_to do |format|
        format.html { redirect_to edit_post_path(@post), notice: t("posts_released_web") }
        format.json { render "posts/show", status: :created }
      end
    else
      render_refusal
    end
  end

  def destroy
    @post.unpublish

    respond_to do |format|
      format.html { redirect_to edit_post_path(@post), notice: t("posts_unpublished") }
      format.json { head :no_content }
    end
  end

  private
    def set_destination
      @destination = @post.destination_for(params[:destination])
    end

    def ensure_destination_offered
      forbid t("posts_destination_not_offered") if @destination.nil?
    end

    # An email-only draft is never published unsent; once it has gone out it may be given a page.
    def ensure_publishable
      if @destination.visibility == "email_only" && !@post.sent?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: t("posts_backdate_not_mailed")), status: :unprocessable_entity }
          format.html { redirect_to edit_post_path(@post), alert: t("posts_backdate_not_mailed") }
          format.json { render json: { error: t("posts_publication_refused_unsent") }, status: :forbidden }
        end
      end
    end

    def published_at
      params[:published_at].presence || Post.on_the_hour(params[:day], params[:hour])
    end
end
