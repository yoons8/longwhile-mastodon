# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Game::BingoService do
  subject(:service) { described_class.new(account) }

  let(:account) { Fabricate(:account) }
  let(:event) { GameBingoEvent.create!(title: '보상 빙고') }
  let(:reward_item) { GameItem.create!(name: '빙고 보상', base_price: 10, item_type: 'miscellaneous') }

  it 'awards the configured item, currency, and reputation once when a bingo level is reached' do
    Array.new(9) { |index| event.items.create!(title: "항목 #{index}") }
    event.rewards.create!(bingo_count: 1, game_item: reward_item, item_quantity: 2, currency: 30, reputation: 4)
    service.boards
    board = event.boards.find_by!(account: account)
    profile = GameProfile.create_or_find_by!(account: account)

    board.item_ids.first(2).each_with_index { |item_id, index| service.submit!(event.id, item_id, "https://example.com/proof-#{index}") }
    expect(profile.reload.currency).to eq(0)

    expect { service.submit!(event.id, board.item_ids.third, 'https://example.com/proof-3') }
      .to change { profile.reload.currency }.by(30)
      .and change { profile.reload.reputation }.by(4)
      .and change { GameInventory.find_by(account: account, game_item: reward_item)&.quantity }.from(nil).to(2)

    expect { service.submit!(event.id, board.item_ids.third, 'https://example.com/again') }.to raise_error(Game::Error, /이미/)
    expect(GameInventory.find_by!(account: account, game_item: reward_item).quantity).to eq(2)
    expect(board.reward_grants.count).to eq(1)
  end
end
