class Journeys::EmailsController < ApplicationController
  include JourneyScoped

  wrap_parameters :journey_email, include: %i[ subject summary body delay_days send_hour ]

  before_action :ensure_admin
  before_action :ensure_addable, only: %i[ new create ]
  before_action :set_email, only: %i[ show edit update destroy ]

  def show
  end

  def new
    @email = @journey.emails.new
  end

  def create
    @email = @journey.emails.new(email_params)

    if @email.save
      respond_to do |format|
        format.html { redirect_to edit_journey_email_path(@journey, @email), notice: t("saved") }
        format.json { render :show, status: :created, location: journey_email_url(@journey, @email, format: :json) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @email.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @email.edit_from_editor(email_params, of_draft: params[:auto_save].present?)
      respond_to do |format|
        format.html { redirect_to edit_journey_email_path(@journey, @email), notice: t("saved") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render_unsaved }
        format.json { render json: @email.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @email.destroy!

    respond_to do |format|
      format.html { redirect_to journey_path(@journey), notice: t("journeys_deleted") }
      format.json { head :no_content }
    end
  end

  private
    def ensure_addable
      head :forbidden unless @journey.addable?
    end

    def set_email
      @email = @journey.emails.find(params[:id])
    end

    def email_params
      params.expect(journey_email: [ :subject, :summary, :body, *(%i[ delay_days send_hour ] if @journey.delayed?) ])
    end

    def render_unsaved
      if @email.errors.any?
        render :edit, status: :unprocessable_entity
      else
        redirect_to edit_journey_email_path(@journey, @email), alert: t("journeys_activated_since")
      end
    end
end
