# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Game' do
  describe 'GET /game' do
    it 'requires the existing Mastodon login' do
      get game_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'uses the signed-in account' do
      user = Fabricate(:user)
      sign_in user

      expect { get game_path }.to change(GameProfile, :count).by(1)
      expect(GameProfile.last.account).to eq(user.account)
    end
  end

  describe 'POST /game/shell_game' do
    it 'rejects zero bets' do
      user = Fabricate(:user)
      sign_in user

      post shell_game_game_path, params: { bet: 0, cup: 1 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(GameTransaction.count).to eq(0)
    end
  end

  describe 'GET /game/state' do
    it 'returns the same item id for shop and inventory matching' do
      user = Fabricate(:user)
      item = GameItem.create!(name: 'Potion', base_price: 20, item_type: 'battle')
      GameInventory.create!(account: user.account, game_item: item, quantity: 1)
      sign_in user

      get state_game_path, as: :json

      expect(response.parsed_body.dig('shops', 0, 'items', 0, 'id')).to eq(item.id)
      expect(response.parsed_body.dig('shops', 0, 'items', 0, 'price')).to eq(item.base_price)
      expect(response.parsed_body.dig('inventory', 0, 'id')).to eq(item.id)
    end

    it 'hides shop items above the current account reputation' do
      user = Fabricate(:user)
      item = GameItem.create!(name: 'Secret', base_price: 20, item_type: 'roleplay', min_reputation: 10)
      GameProfile.create!(account: user.account, reputation: 9)
      sign_in user

      get state_game_path, as: :json

      expect(response.parsed_body.dig('shops', 0, 'items')).to be_empty
    end
  end
end
