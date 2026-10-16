class Posts::TestDeliveriesController < ApplicationController
  include PostScoped

  wrap_parameters :post, include: %i[ title summary body visibility ]

  before_action :ensure_admin
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { Current.user.id }, with: -> { head :too_many_requests }

  # The test is sent from the editor's bar, so every answer is a flash and the editor stays as it is.
  def create
    if !save_post
      refuse_unsaved
    elsif @post.deliver_test_to(email_address)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash(notice: t("posts_test_sent", email_address: email_address)) }
        format.html { redirect_to edit_post_path(@post), notice: t("posts_test_sent", email_address: email_address) }
        format.json { head :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: refusal), status: :unprocessable_entity }
        format.html { redirect_to edit_post_path(@post), alert: refusal }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def refuse_unsaved
      if @post.errors.any?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: t("posts_test_not_sent", reason: @post.errors.full_messages.to_sentence)), status: :unprocessable_entity }
          format.html { redirect_to edit_post_path(@post), alert: t("posts_test_not_sent", reason: @post.errors.full_messages.to_sentence) }
          format.json { render json: @post.errors, status: :unprocessable_entity }
        end
      else
        redirect_to edit_post_path(@post), alert: t("posts_published_since")
      end
    end

    def email_address
      params.fetch(:email_address, Current.identity.email_address).to_s.strip
    end

    # A wrong address is a sentence of its own; a missing sender is told as what it stopped.
    def refusal
      if @post.errors.include?(:sender)
        t("posts_test_not_sent", reason: @post.errors[:sender].to_sentence)
      else
        @post.errors.full_messages.to_sentence
      end
    end
end
