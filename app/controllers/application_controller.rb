class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def current_player
    current_user&.player
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    redirect_to root_path, alert: "ログインしてください。" unless logged_in?
  end
end
