# frozen_string_literal: true

class AddMarketPricingToGameItems < ActiveRecord::Migration[8.0]
  def change
    add_column :game_items, :market_enabled, :boolean, null: false, default: false
    add_column :game_items, :market_price, :bigint
    add_column :game_items, :previous_market_price, :bigint
    add_column :game_items, :market_min_price, :bigint
    add_column :game_items, :market_max_price, :bigint
    add_column :game_items, :market_volatility, :integer, null: false, default: 10
    add_column :game_items, :market_price_updated_at, :datetime

    safety_assured do
      add_check_constraint :game_items, 'market_price IS NULL OR market_price >= 0', name: 'game_items_market_price_nonnegative'
      add_check_constraint :game_items, 'previous_market_price IS NULL OR previous_market_price >= 0', name: 'game_items_previous_market_price_nonnegative'
      add_check_constraint :game_items, 'market_min_price IS NULL OR market_min_price >= 0', name: 'game_items_market_min_price_nonnegative'
      add_check_constraint :game_items, 'market_max_price IS NULL OR market_max_price >= 0', name: 'game_items_market_max_price_nonnegative'
      add_check_constraint :game_items, 'market_volatility >= 0 AND market_volatility <= 100', name: 'game_items_market_volatility_range'
    end
  end
end
