class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    ActiveRecord::Base.transaction do
      @user.save!
      PlayerInitializer.create_for_user!(@user)
    end

    session[:user_id] = @user.id
    redirect_to game_path, notice: "登録しました。ゲームを開始します。"
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @user.errors.full_messages.join("、")
    render :new, status: :unprocessable_entity
  end

  private

  def user_params
    params.require(:user).permit(:username, :password)
  end
end
