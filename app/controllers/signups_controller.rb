class SignupsController < ApplicationController
  include TenantLimited

  wrap_parameters :signup, include: %i[ email_address ]

  disallow_account_scope
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: t("sessions_rate_limit_exceeded_3min") }
  before_action :redirect_authenticated_user
  before_action :enforce_tenant_limit

  layout "public"

  def new
    @signup = Signup.new
  end

  def create
    signup = Signup.new(signup_params)
    if signup.valid?(:identity_creation)
      redirect_to_session_magic_link signup.create_identity
    else
      head :unprocessable_entity
    end
  end

  private
    def redirect_authenticated_user
      redirect_to new_signup_completion_path if authenticated?
    end

    def signup_params
      params.expect signup: :email_address
    end
end
