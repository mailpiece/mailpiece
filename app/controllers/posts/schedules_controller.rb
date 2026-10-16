class Posts::SchedulesController < ApplicationController
  include PostScoped, PostReleasing

  wrap_parameters :post, include: %i[ title summary body ]

  before_action :ensure_admin
  before_action :ensure_draft, :set_destination, :ensure_destination_offered, only: :create

  def create
    if save_post && @post.schedule_to(@destination, at: scheduled_at)
      respond_to do |format|
        format.html { redirect_to edit_post_path(@post), notice: t("status_scheduled") }
        format.json { render "posts/show", status: :created }
      end
    else
      render_refusal
    end
  end

  def destroy
    @post.unschedule

    respond_to do |format|
      format.html { redirect_to edit_post_path(@post), notice: t("posts_schedule_cancelled") }
      format.json { head :no_content }
    end
  end

  private
    def ensure_draft
      unless @post.draft?
        respond_to do |format|
          format.html { redirect_to edit_post_path(@post), alert: t("posts_published_since") }
          format.json { render json: { error: t("posts_schedule_refused_not_draft") }, status: :forbidden }
        end
      end
    end

    def set_destination
      @destination = @post.destination_for(params[:destination], mailed: scheduled_delivery?)
    end

    def ensure_destination_offered
      forbid t("posts_destination_not_offered") if @destination.nil?
    end

    def scheduled_delivery?
      ActiveModel::Type::Boolean.new.cast(params[:scheduled_delivery]).present?
    end

    def scheduled_at
      params[:scheduled_posting_at] || Post.on_the_hour(params[:day], params[:hour])
    end
end
