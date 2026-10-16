class HostsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_account

  def show
    if Account.answers_at?(AccountDomain.normalize(params[:host]))
      head :ok
    else
      head :not_found
    end
  end
end
