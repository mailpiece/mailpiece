class Posts::RevisionsController < ApplicationController
  include PostScoped

  before_action :ensure_admin
  before_action :set_revision, only: :show

  def index
    @revisions = @post.revisions.order(:id).preload(:creator)
  end

  def show
  end

  private
    def set_revision
      if params[:id] == "latest"
        @revision = @post.revisions.last!
      else
        @revision = @post.revisions.find(params[:id])
      end
    end
end
