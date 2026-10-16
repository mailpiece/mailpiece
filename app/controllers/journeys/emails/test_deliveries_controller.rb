class Journeys::Emails::TestDeliveriesController < ApplicationController
  include JourneyEmailScoped

  wrap_parameters :journey_email, include: %i[ subject summary body delay_days send_hour ]

  before_action :ensure_admin
  rate_limit to: 10, within: 3.minutes, only: :create, by: -> { Current.user.id }, with: -> { head :too_many_requests }

  # The test is sent from the editor's bar, so every answer is a flash and the editor stays as it is.
  def create
    if !save_email
      refuse_unsaved
    elsif @email.deliver_test_to(email_address)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash(notice: t("posts_test_sent", email_address: email_address)) }
        format.html { redirect_to edit_journey_email_path(@journey, @email), notice: t("posts_test_sent", email_address: email_address) }
        format.json { head :created }
      end
    else
      refuse refusal
    end
  end

  private
    # An email that could not be saved is told as what stopped the test.
    def refuse_unsaved
      if @email.errors.any?
        refuse t("posts_test_not_sent", reason: @email.errors.full_messages.to_sentence)
      else
        render_refusal
      end
    end

    def email_address
      params.fetch(:email_address, Current.identity.email_address).to_s.strip
    end

    # A wrong address or a blank email is a sentence of its own; a missing sender is told as what it stopped.
    def refusal
      if @email.errors.include?(:sender)
        t("posts_test_not_sent", reason: @email.errors[:sender].to_sentence)
      else
        @email.errors.full_messages.to_sentence
      end
    end
end
