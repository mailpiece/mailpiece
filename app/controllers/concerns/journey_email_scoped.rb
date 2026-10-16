module JourneyEmailScoped
  extend ActiveSupport::Concern

  included do
    include JourneyScoped

    before_action :set_email
  end

  private
    def set_email
      @email = @journey.emails.find(params[:email_id])
    end

    def save_email
      @email.edit_from_editor(email_params, of_draft: params[:auto_save].present?)
    end

    def render_refusal
      if @email.errors.any?
        refuse @email.errors.full_messages.to_sentence
      else
        redirect_to edit_journey_email_path(@journey, @email), alert: t("journeys_activated_since")
      end
    end

    def refuse(reason)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: reason), status: :unprocessable_entity }
        format.html { redirect_to edit_journey_email_path(@journey, @email), alert: reason }
        format.json { render json: @email.errors, status: :unprocessable_entity }
      end
    end

    # Optional: a request may switch on or test the email as it is, with none of its fields.
    def email_params
      params.fetch(:journey_email, {}).permit(:subject, :summary, :body, *(%i[ delay_days send_hour ] if @journey.delayed?))
    end
end
