# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin game players' do
  let(:account) { Fabricate(:account, username: 'game_player') }
  let!(:profile) { GameProfile.create!(account: account, currency: 25, reputation: 7) }

  it 'rejects a regular user' do
    sign_in Fabricate(:user)

    get admin_game_players_path

    expect(response).to have_http_status(403)
  end

  it 'shows game profile details to an administrator' do
    item = GameItem.create!(name: '관리자 확인용 아이템', base_price: 1, item_type: 'miscellaneous')
    GameInventory.create!(account: account, game_item: item, quantity: 2)
    sign_in Fabricate(:admin_user)

    get admin_game_players_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('@game_player')

    get admin_game_player_path(profile)
    expect(response).to have_http_status(:success)
    expect(response.body).to include('관리자 확인용 아이템')
  end
end
