class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(username: params[:username].to_s.strip.downcase)

    if user&.authenticate(params[:password].to_s)
      session[:user_id] = user.id
      redirect_to game_path, notice: "ログインしました。"
    else
      flash.now[:alert] = "ユーザー名またはパスワードが違います。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました。"
  end
end
