# frozen_string_literal: true

class CreateGameBingoRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :game_bingo_rewards do |t|
      t.references :game_bingo_event, null: false, foreign_key: { on_delete: :cascade }
      t.integer :bingo_count, null: false
      t.references :game_item, foreign_key: { on_delete: :restrict }
      t.integer :item_quantity, null: false, default: 0
      t.bigint :currency, null: false, default: 0
      t.integer :reputation, null: false, default: 0
      t.timestamps
    end
    add_index :game_bingo_rewards, [:game_bingo_event_id, :bingo_count], unique: true, name: 'index_game_bingo_rewards_unique_level'

    create_table :game_bingo_reward_grants do |t|
      t.references :game_bingo_board, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_bingo_reward, null: false, foreign_key: { on_delete: :restrict }
      t.references :game_item, foreign_key: { on_delete: :restrict }
      t.integer :bingo_count, null: false
      t.integer :item_quantity, null: false, default: 0
      t.bigint :currency, null: false, default: 0
      t.integer :reputation, null: false, default: 0
      t.timestamps
    end
    add_index :game_bingo_reward_grants, [:game_bingo_board_id, :game_bingo_reward_id], unique: true, name: 'index_game_bingo_reward_grants_unique_level'

    safety_assured do
      add_check_constraint :game_bingo_rewards, 'bingo_count >= 1 AND bingo_count <= 8', name: 'game_bingo_rewards_count_range'
      add_check_constraint :game_bingo_rewards, 'item_quantity >= 0 AND currency >= 0 AND reputation >= 0', name: 'game_bingo_rewards_values_nonnegative'
      add_check_constraint :game_bingo_reward_grants, 'bingo_count >= 1 AND bingo_count <= 8', name: 'game_bingo_reward_grants_count_range'
      add_check_constraint :game_bingo_reward_grants, 'item_quantity >= 0 AND currency >= 0 AND reputation >= 0', name: 'game_bingo_reward_grants_values_nonnegative'
    end
  end
end
