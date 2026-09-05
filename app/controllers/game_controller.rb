# frozen_string_literal: true

class GameController < ApplicationController
  include WebAppControllerConcern

  before_action :authenticate_user!
  before_action :ensure_profile

  rescue_from Game::Error, with: :render_game_error

  def show
    render 'home/index'
  end

  def state
    render json: state_payload
  end

  def purchase
    render json: Game::EconomyService.new(current_account).purchase!(params[:game_item_id])
  end

  def sell
    render json: Game::EconomyService.new(current_account).sell!(params[:game_item_id], params[:quantity])
  end

  def talk
    render json: Game::EconomyService.new(current_account).talk!
  end

  def vend
    render json: Game::EconomyService.new(current_account).vend!
  end

  def shell_game
    render json: Game::EconomyService.new(current_account).shell_game!(params[:bet], params[:cup])
  end

  def start_simon
    render json: Game::SimonService.new(current_account).start!
  end

  def submit_simon
    render json: Game::SimonService.new(current_account).submit!(params[:token], params[:sequence])
  end

  private

  def ensure_profile
    @game_profile = GameProfile.create_or_find_by!(account: current_account)
  end

  def state_payload
    inventories = GameInventory.owned.where(account: current_account).joins(:game_item).includes(:game_item).order(game_items: { name: :asc })
    items = GameItem.visible_to(@game_profile.reputation).order(:name)

    {
      profile: { currency: @game_profile.currency, reputation: @game_profile.reputation },
      inventory: inventories.map { |inventory| inventory_payload(inventory) },
      shops: [{ id: 0, name: '상점', description: '구매 가능한 아이템입니다.', shop_type: 'normal', items: items.map { |item| shop_item_payload(item) } }],
    }
  end

  def inventory_payload(inventory)
    item = inventory.game_item
    {
      id: item.id,
      name: item.name,
      description: item.description,
      image: item.image.exists? ? item.image.url(:small) : nil,
      consumable: item.consumable,
      quantity: inventory.quantity,
      sale_price: (item.base_price * Game::EconomyService::SALE_RATE).floor,
    }
  end

  def shop_item_payload(item)
    {
      id: item.id,
      name: item.name,
      description: item.description,
      image: item.image.exists? ? item.image.url(:small) : nil,
      consumable: item.consumable,
      price: item.base_price,
      min_reputation: item.min_reputation,
    }
  end

  def render_game_error(error)
    render json: { error: error.message, code: error.code }, status: :unprocessable_entity
  end
end
