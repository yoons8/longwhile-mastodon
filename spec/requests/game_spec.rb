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

    it 'returns the current market price and its change' do
      user = Fabricate(:user)
      GameItem.create!(name: 'Market Potion', base_price: 20, item_type: 'battle', market_enabled: true, market_price: 30, previous_market_price: 25, market_price_updated_at: Time.current)
      sign_in user

      get state_game_path, as: :json

      market_item = response.parsed_body.dig('shops', 0, 'items', 0)
      expect(market_item).to include('price' => 30, 'market_enabled' => true, 'market_change_percent' => 20.0)
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

  describe 'POST /game/survival_events/:id/choose' do
    let(:user) { Fabricate(:user) }
    let(:reward_items) { Array.new(7) { |index| GameItem.create!(name: "생존 보상 #{index}", base_price: 0, item_type: 'miscellaneous') } }
    let(:event) { GameSurvivalEvent.create!(title: '세 갈래 길', failure_messages: Array.new(7) { |index| "탈락 문구 #{index}" }, reward_item_ids: reward_items.map(&:id)) }

    before do
      event.steps.create!(position: 1, title: '첫 번째 길', choices: %w(왼쪽 가운데 오른쪽), survival_choice: 1)
      event.steps.create!(position: 2, title: '두 번째 길', choices: %w(산 강 들판), survival_choice: 2)
      sign_in user
    end

    it 'moves a survivor to the next step and completes the final step' do
      post choose_game_survival_event_path(event), params: { choice: 1 }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('survived' => true, 'status' => 'in_progress', 'current_step' => 1)

      post choose_game_survival_event_path(event), params: { choice: 2 }, as: :json

      expect(response.parsed_body).to include('survived' => true, 'status' => 'completed', 'current_step' => 2)
      expect(event.entries.find_by(account: user.account).results.size).to eq(2)
      expect(GameInventory.find_by(account: user.account, game_item: reward_items).quantity).to eq(1)
    end

    it 'stops the event immediately after an eliminating choice' do
      post choose_game_survival_event_path(event), params: { choice: 0 }, as: :json
      post choose_game_survival_event_path(event), params: { choice: 1 }, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body['code']).to eq('event_finished')
      expect(event.entries.where(account: user.account).count).to eq(1)
      expect(event.entries.find_by(account: user.account).outcome_message).to start_with('탈락 문구')
    end

    it 'rejects inactive events' do
      event.update!(active: false)

      post choose_game_survival_event_path(event), params: { choice: 1 }, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body['code']).to eq('event_unavailable')
    end
  end
end
