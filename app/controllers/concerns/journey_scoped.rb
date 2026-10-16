module JourneyScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_journey
  end

  private
    def set_journey
      raise ActiveRecord::RecordNotFound unless Journey::TRIGGERS.include?(params[:journey_trigger])
      @journey = Current.account.journey_triggered_by(params[:journey_trigger])
    end
end
