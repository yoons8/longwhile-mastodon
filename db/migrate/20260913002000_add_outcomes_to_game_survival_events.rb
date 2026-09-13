# frozen_string_literal: true

class AddOutcomesToGameSurvivalEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :game_survival_events, :failure_messages, :jsonb, null: false, default: []

    create_table :game_survival_event_rewards do |t|
      t.references :game_survival_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_item, null: false, foreign_key: { on_delete: :restrict }
      t.timestamps
    end
    add_index :game_survival_event_rewards, [:game_survival_event_id, :game_item_id], unique: true, name: 'index_game_survival_event_rewards_unique_item'

    add_column :game_survival_event_entries, :outcome_message, :text
    safety_assured do
      add_reference :game_survival_event_entries, :reward_game_item, foreign_key: { to_table: :game_items, on_delete: :restrict }, index: true
    end
  end
end
