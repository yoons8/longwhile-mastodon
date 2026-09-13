# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Game::MarketPriceService do
  describe '.refresh_all!' do
    it 'updates enabled item prices within the configured range' do
      item = GameItem.create!(name: '변동 아이템', base_price: 100, item_type: 'miscellaneous', market_enabled: true, market_price: 100, market_min_price: 95, market_max_price: 105, market_volatility: 20)
      fixed_item = GameItem.create!(name: '고정 아이템', base_price: 100, item_type: 'miscellaneous')
      allow(SecureRandom).to receive(:random_number).and_return(40)

      described_class.refresh_all!

      expect(item.reload).to have_attributes(previous_market_price: 100, market_price: 105)
      expect(item.market_price_updated_at).to be_present
      expect(fixed_item.reload.market_price).to be_nil
    end
  end
end
