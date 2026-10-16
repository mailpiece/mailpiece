class PostsController < ApplicationController
  wrap_parameters :post, include: %i[ title summary body visibility published_at ]

  before_action :ensure_admin
  before_action :set_post, only: %i[ show edit update destroy ]
  before_action :set_release, only: %i[ edit update ]

  def index
    @drafts = Current.account.posts.drafts.unscheduled.reverse_chronologically.preloaded
    @scheduled = Current.account.posts.scheduled.latest_first.preloaded
  end

  def show
  end

  def new
    @post = Current.account.posts.new
  end

  def create
    @post = Current.account.posts.new(post_params)

    if @post.save
      respond_to do |format|
        format.html { redirect_to edit_post_path(@post), notice: t("saved") }
        format.json { render :show, status: :created, location: post_url(@post, format: :json) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @post.edit_from_editor(post_params, of_draft: params[:auto_save].present?)
      respond_to do |format|
        format.html { redirect_to edit_post_path(@post), notice: t("saved") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render_unsaved }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @post.destroy!

    respond_to do |format|
      format.html { redirect_to posts_path, notice: t("posts_deleted") }
      format.json { head :no_content }
    end
  end

  private
    def set_post
      @post = Current.account.posts.find(params[:id])
    end

    # The editor's bar offers the release, so it is drawn with the count and the destination proposed.
    def set_release
      @release = Post::Release.new(@post)
    end

    # The date is taken only for a post already on the web, so a save never publishes a draft.
    def post_params
      params.expect(post: [ :title, :summary, :body, :visibility, *(%i[ published_at published_day published_hour ] if @post&.redatable?) ])
    end

    def render_unsaved
      if @post.errors.any?
        render :edit, status: :unprocessable_entity
      else
        redirect_to edit_post_path(@post), alert: t("posts_published_since")
      end
    end
end
