# frozen_string_literal: true

class CreateGameBingoEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_bingo_events do |t|
      t.string :title, null: false
      t.text :description, null: false, default: ''
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end
    add_index :game_bingo_events, [:active, :starts_at, :ends_at], name: 'index_game_bingo_events_on_availability'

    create_table :game_bingo_items do |t|
      t.references :game_bingo_event, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :description, null: false, default: ''
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :game_bingo_boards do |t|
      t.references :game_bingo_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :item_ids, null: false, default: []
      t.datetime :completed_at
      t.timestamps
    end
    add_index :game_bingo_boards, [:game_bingo_event_id, :account_id], unique: true, name: 'index_game_bingo_boards_unique_player'

    create_table :game_bingo_submissions do |t|
      t.references :game_bingo_board, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_bingo_item, null: false, foreign_key: { on_delete: :restrict }
      t.text :url, null: false
      t.timestamps
    end
    add_index :game_bingo_submissions, [:game_bingo_board_id, :game_bingo_item_id], unique: true, name: 'index_game_bingo_submissions_unique_cell'
  end
end
