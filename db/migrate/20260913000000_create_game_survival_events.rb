# frozen_string_literal: true

class CreateGameSurvivalEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_survival_events do |t|
      t.string :title, null: false
      t.text :description, null: false, default: ''
      t.jsonb :choices, null: false, default: []
      t.integer :survival_choice, null: false
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end
    add_index :game_survival_events, [:active, :starts_at, :ends_at], name: 'index_game_survival_events_on_availability'
    add_check_constraint :game_survival_events, 'survival_choice >= 0 AND survival_choice <= 2', name: 'game_survival_events_survival_choice_check'

    create_table :game_survival_event_entries do |t|
      t.references :game_survival_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.integer :choice, null: false
      t.boolean :survived, null: false, default: false
      t.timestamps
    end
    add_index :game_survival_event_entries, [:game_survival_event_id, :account_id], unique: true, name: 'index_game_survival_event_entries_unique_participant'
    add_check_constraint :game_survival_event_entries, 'choice >= 0 AND choice <= 2', name: 'game_survival_event_entries_choice_check'
  end
end
