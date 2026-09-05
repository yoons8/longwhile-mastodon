# frozen_string_literal: true

class CreateGameBattleSystem < ActiveRecord::Migration[8.0]
  def change
    add_column :game_items, :battle_action, :string
    add_column :game_items, :dice_count, :integer
    add_column :game_items, :dice_sides, :integer
    add_column :game_items, :flat_bonus, :integer, null: false, default: 0

    add_check_constraint :game_items, "battle_action IS NULL OR battle_action IN ('attack', 'defense')", name: 'game_items_battle_action_check', validate: false
    add_check_constraint :game_items, 'dice_count IS NULL OR dice_count BETWEEN 1 AND 10', name: 'game_items_dice_count_check', validate: false
    add_check_constraint :game_items, 'dice_sides IS NULL OR dice_sides BETWEEN 2 AND 100', name: 'game_items_dice_sides_check', validate: false

    create_table :game_battles do |t|
      t.references :challenger_account, null: false, foreign_key: { to_table: :accounts }, index: false
      t.references :opponent_account, null: false, foreign_key: { to_table: :accounts }, index: false
      t.references :winner_account, foreign_key: { to_table: :accounts }, index: false
      t.references :loser_account, foreign_key: { to_table: :accounts }, index: false
      t.references :revenge_of, foreign_key: { to_table: :game_battles }, index: false
      t.string :state, null: false, default: 'pending'
      t.integer :current_turn, null: false, default: 0
      t.integer :challenger_hp, null: false
      t.integer :opponent_hp, null: false
      t.datetime :finished_at
      t.datetime :revenge_used_at
      t.datetime :kill_used_at
      t.timestamps
    end

    add_index :game_battles, [:challenger_account_id, :state]
    add_index :game_battles, [:opponent_account_id, :state]
    add_index :game_battles, [:loser_account_id, :finished_at]
    add_check_constraint :game_battles, "state IN ('pending', 'active', 'finished', 'cancelled', 'rejected')", name: 'game_battles_state_check'
    add_check_constraint :game_battles, 'challenger_account_id <> opponent_account_id', name: 'game_battles_distinct_accounts_check'
    add_check_constraint :game_battles, 'current_turn >= 0', name: 'game_battles_turn_check'
    add_check_constraint :game_battles, 'challenger_hp >= 0 AND opponent_hp >= 0', name: 'game_battles_hp_check'

    create_table :game_battle_turns do |t|
      t.references :game_battle, null: false, foreign_key: true
      t.integer :turn_number, null: false
      t.string :challenger_action
      t.string :opponent_action
      t.references :challenger_item, foreign_key: { to_table: :game_items }, index: false
      t.references :opponent_item, foreign_key: { to_table: :game_items }, index: false
      t.string :challenger_status_id
      t.string :opponent_status_id
      t.jsonb :result, null: false, default: {}
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :game_battle_turns, [:game_battle_id, :turn_number], unique: true
    add_index :game_battle_turns, :challenger_status_id, unique: true, where: 'challenger_status_id IS NOT NULL'
    add_index :game_battle_turns, :opponent_status_id, unique: true, where: 'opponent_status_id IS NOT NULL'
    add_check_constraint :game_battle_turns, "challenger_action IS NULL OR challenger_action IN ('attack', 'defense')", name: 'game_battle_turns_challenger_action_check'
    add_check_constraint :game_battle_turns, "opponent_action IS NULL OR opponent_action IN ('attack', 'defense')", name: 'game_battle_turns_opponent_action_check'
    add_check_constraint :game_battle_turns, 'turn_number >= 1', name: 'game_battle_turns_number_check'

    create_table :game_bot_events do |t|
      t.string :status_id, null: false
      t.references :account, null: false, foreign_key: true
      t.string :command, null: false
      t.jsonb :response, null: false, default: {}
      t.timestamps
    end

    add_index :game_bot_events, :status_id, unique: true
  end
end
