class UsersController < ApplicationController
  wrap_parameters :user, include: %i[ name ]

  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_path(@user), notice: t("users_profile_updated") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_user
      @user = Current.account.users.active.where(identity: Current.identity).find(params[:id])
    end

    def user_params
      params.expect(user: [ :name ])
    end
end
