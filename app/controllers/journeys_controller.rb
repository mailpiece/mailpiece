class JourneysController < ApplicationController
  before_action :ensure_admin
  before_action :set_journey, only: :show

  def index
    @journeys = Current.account.journeys
  end

  def show
  end

  private
    def set_journey
      raise ActiveRecord::RecordNotFound unless Journey::TRIGGERS.include?(params[:trigger])
      @journey = Current.account.journey_triggered_by(params[:trigger])
    end
end
