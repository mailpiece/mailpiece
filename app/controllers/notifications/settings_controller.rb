class Notifications::SettingsController < ApplicationController
  wrap_parameters :user_settings, include: %i[ new_subscriber_notifications ]

  before_action :ensure_admin
  before_action :set_settings

  def show
  end

  def update
    @settings.update!(settings_params)

    respond_to do |format|
      format.html { redirect_to notifications_settings_path, notice: t("settings_saved") }
      format.json { head :no_content }
    end
  end

  private
    def set_settings
      @settings = Current.user.settings
    end

    def settings_params
      params.expect(user_settings: :new_subscriber_notifications)
    end
end
