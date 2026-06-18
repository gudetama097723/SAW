class HomeController < ApplicationController
  def index
    redirect_to game_path if logged_in?
  end
end
