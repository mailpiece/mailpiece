module PostReleasing
  extend ActiveSupport::Concern

  private
    def render_refusal
      if @post.errors.any?
        refuse @post.errors.full_messages.to_sentence
      else
        redirect_to edit_post_path(@post), alert: t("posts_published_since")
      end
    end

    def refuse(reason)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: reason), status: :unprocessable_entity }
        format.html { redirect_to edit_post_path(@post), alert: reason }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
end
