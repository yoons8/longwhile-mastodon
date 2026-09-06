# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Game::EconomyService do
  subject(:service) { described_class.new(account) }

  let(:account) { Fabricate(:account) }
  let!(:profile) { GameProfile.create!(account: account, currency: 100, reputation: 10) }
  let!(:item) { GameItem.create!(name: 'Potion', description: 'Heals', base_price: 40, item_type: 'battle', consumable: true) }

  describe '#purchase!' do
    it 'uses the server price and atomically updates all records' do
      expect { service.purchase!(item.id) }
        .to change { profile.reload.currency }.from(100).to(60)
        .and change { GameInventory.find_by(account: account, game_item: item)&.quantity }.from(nil).to(1)
        .and change(GameTransaction, :count).by(1)
    end

    it 'rejects a product whose item reputation requirement is not met' do
      item.update!(min_reputation: 11)

      expect { service.purchase!(item.id) }.to raise_error(Game::Error, /구매할 수 없는/)
      expect(profile.reload.currency).to eq(100)
    end

    it 'does not limit the number of purchases per day' do
      profile.update!(currency: 1_000)

      4.times { service.purchase!(item.id) }

      expect(GameInventory.find_by!(account: account, game_item: item).quantity).to eq(4)
      expect(GameDailyUsage.where(account: account, action_type: 'purchase')).to be_empty
    end
  end

  describe '#sell!' do
    it 'rejects non-positive quantities' do
      expect { service.sell!(item.id, 0) }.to raise_error(Game::Error)
    end

    it 'only sells owned quantity at half the base price' do
      GameInventory.create!(account: account, game_item: item, quantity: 2)

      expect { service.sell!(item.id, 1) }.to change { profile.reload.currency }.by(20)
      expect(GameInventory.find_by!(account: account, game_item: item).quantity).to eq(1)
    end
  end

  describe '#shell_game!' do
    it 'rejects invalid bets without consuming daily usage' do
      expect { service.shell_game!(-1, 1) }.to raise_error(Game::Error)
      expect(GameDailyUsage.count).to eq(0)
    end

    it 'enforces the server-side daily limit' do
      allow(SecureRandom).to receive(:random_number).and_return(0)
      3.times { service.shell_game!(1, 1) }

      expect { service.shell_game!(1, 1) }.to raise_error(Game::Error, /횟수/)
      expect(GameDailyUsage.find_by!(account: account, action_type: 'shell_game').count).to eq(3)
    end

    it 'keeps daily usage separate for each action type' do
      allow(SecureRandom).to receive(:random_number).and_return(0)

      service.shell_game!(1, 1)
      service.talk!

      expect(GameDailyUsage.find_by!(account: account, action_type: 'shell_game').count).to eq(1)
      expect(GameDailyUsage.find_by!(account: account, action_type: 'talk').count).to eq(1)
    end
  end
end
