# frozen_string_literal: true

module Game
  class MarketPriceService
    def self.refresh_all!
      GameItem.where(market_enabled: true).find_each { |item| new(item).refresh! }
    end

    def initialize(item)
      @item = item
    end

    def refresh!
      @item.with_lock do
        old_price = @item.effective_price
        change_percent = SecureRandom.random_number((@item.market_volatility * 2) + 1) - @item.market_volatility
        new_price = (old_price * (100 + change_percent) / 100.0).round
        new_price = [new_price, minimum_price].max
        new_price = [new_price, maximum_price].min if maximum_price

        @item.update!(previous_market_price: old_price, market_price: new_price, market_price_updated_at: Time.current)
      end
    end

    private

    def minimum_price
      @item.market_min_price || 0
    end

    def maximum_price
      @item.market_max_price
    end
  end
end
