# frozen_string_literal: true

class AddCellRewardsToGameBingoItems < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_reference :game_bingo_items, :reward_game_item, foreign_key: { to_table: :game_items, on_delete: :restrict }
      add_column :game_bingo_items, :reward_item_quantity, :integer, null: false, default: 0
      add_column :game_bingo_items, :reward_currency, :bigint, null: false, default: 0
      add_column :game_bingo_items, :reward_reputation, :integer, null: false, default: 0

      add_reference :game_bingo_submissions, :reward_game_item, foreign_key: { to_table: :game_items, on_delete: :restrict }
      add_column :game_bingo_submissions, :reward_item_quantity, :integer, null: false, default: 0
      add_column :game_bingo_submissions, :reward_currency, :bigint, null: false, default: 0
      add_column :game_bingo_submissions, :reward_reputation, :integer, null: false, default: 0
      add_column :game_bingo_submissions, :rewarded_at, :datetime

      add_check_constraint :game_bingo_items, 'reward_item_quantity >= 0 AND reward_currency >= 0 AND reward_reputation >= 0', name: 'game_bingo_items_reward_values_nonnegative'
      add_check_constraint :game_bingo_submissions, 'reward_item_quantity >= 0 AND reward_currency >= 0 AND reward_reputation >= 0', name: 'game_bingo_submissions_reward_values_nonnegative'
    end
  end
end
