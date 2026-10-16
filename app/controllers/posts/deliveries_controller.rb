class Posts::DeliveriesController < ApplicationController
  include PostScoped

  before_action :ensure_admin

  def create
    started = @post.deliver

    respond_to do |format|
      format.json do
        if @post.errors.none?
          render "posts/show", status: (started ? :created : :ok)
        else
          render json: @post.errors, status: :unprocessable_entity
        end
      end
    end
  end
end
