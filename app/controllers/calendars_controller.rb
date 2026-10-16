class CalendarsController < ApplicationController
  before_action :ensure_admin

  def show
    redirect_to calendar_agenda_path(Time.zone.today.iso8601)
  end
end
