class StarterWeaponsController < ApplicationController
  before_action :require_login
  before_action :set_player
  before_action :redirect_if_already_selected

  def show
    @starter_weapons = StarterWeaponCatalog.all
  end

  def create
    choice = StarterWeaponCatalog.find(params[:starter_weapon])

    if PlayerInitializer.choose_initial_weapon!(@player, choice)
      redirect_to game_path, notice: "#{choice.name}を装備しました。ゲームを開始します。"
    else
      @starter_weapons = StarterWeaponCatalog.all
      flash.now[:alert] = "初期武器を選んでください。"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_player
    @player = current_player
    redirect_to root_path, alert: "プレイヤーが見つかりません。" if @player.blank?
  end

  def redirect_if_already_selected
    redirect_to game_path if @player&.weapons&.exists?
  end
end
