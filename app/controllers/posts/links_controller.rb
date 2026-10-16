class Posts::LinksController < ApplicationController
  include PostScoped

  wrap_parameters :post_link, include: %i[ url ]

  before_action :ensure_admin
  before_action :set_link, only: %i[ edit update ]

  def index
    @links = @post.links
  end

  def edit
  end

  def update
    if @link.update(link_params)
      respond_to do |format|
        format.html { redirect_to post_results_path(@post) }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @link.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_link
      @link = @post.links.find(params[:id])
    end

    def link_params
      params.expect(post_link: [ :url ])
    end
end
