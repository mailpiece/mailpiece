module PostScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_post
  end

  private
    def set_post
      @post = Current.account.posts.find(params[:post_id])
    end

    def forbid(reason)
      if request.format.json?
        render json: { error: reason }, status: :forbidden
      else
        head :forbidden
      end
    end

    def save_post
      @post.edit_from_editor(post_params, of_draft: params[:auto_save].present?)
    end

    # Optional: a request may release or test the post as it is, with none of its fields.
    def post_params
      params.fetch(:post, {}).permit(:title, :summary, :body, :visibility, *(:published_at if @post.redatable?))
    end
end
