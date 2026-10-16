class Journeys::Emails::ActivationsController < ApplicationController
  include JourneyEmailScoped

  wrap_parameters :journey_email, include: %i[ subject summary body delay_days send_hour ]

  before_action :ensure_admin

  # Switched on from the editor's bar, so a refusal is a flash and the editor stays as it is.
  def create
    if save_email && @email.activate
      respond_to do |format|
        format.html { redirect_to journey_path(@journey), notice: t("journeys_activated") }
        format.json { render "journeys/emails/show", status: :created }
      end
    else
      render_refusal
    end
  end

  def destroy
    @email.deactivate

    respond_to do |format|
      format.html { redirect_to journey_path(@journey), notice: t("journeys_deactivated") }
      format.json { head :no_content }
    end
  end
end
