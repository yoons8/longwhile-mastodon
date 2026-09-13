# frozen_string_literal: true

class AddDepthToGameSurvivalEvents < ActiveRecord::Migration[8.0]
  def up
    create_table :game_survival_event_steps do |t|
      t.references :game_survival_event, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :title, null: false
      t.text :description, null: false, default: ''
      t.jsonb :choices, null: false, default: []
      t.integer :survival_choice, null: false
      t.timestamps
    end
    add_index :game_survival_event_steps, [:game_survival_event_id, :position], unique: true, name: 'index_game_survival_event_steps_unique_position'
    add_check_constraint :game_survival_event_steps, 'position >= 1', name: 'game_survival_event_steps_position_check'
    add_check_constraint :game_survival_event_steps, 'survival_choice >= 0 AND survival_choice <= 2', name: 'game_survival_event_steps_survival_choice_check'

    safety_assured do
      execute <<~SQL.squish
        INSERT INTO game_survival_event_steps
          (game_survival_event_id, position, title, description, choices, survival_choice, created_at, updated_at)
        SELECT id, 1, title, description, choices, survival_choice, created_at, updated_at
        FROM game_survival_events
      SQL
    end

    change_column_default :game_survival_events, :survival_choice, from: nil, to: 0
    add_column :game_survival_event_entries, :current_step_index, :integer, null: false, default: 0
    add_column :game_survival_event_entries, :status, :string, null: false, default: 'in_progress'
    add_column :game_survival_event_entries, :results, :jsonb, null: false, default: []
    safety_assured { add_index :game_survival_event_entries, :status }
    safety_assured do
      add_check_constraint :game_survival_event_entries, "status IN ('in_progress', 'completed', 'eliminated')", name: 'game_survival_event_entries_status_check'
      add_check_constraint :game_survival_event_entries, 'current_step_index >= 0', name: 'game_survival_event_entries_current_step_check'
    end

    safety_assured do
      execute <<~SQL.squish
        UPDATE game_survival_event_entries AS entries
        SET status = CASE WHEN survived THEN 'completed' ELSE 'eliminated' END,
            current_step_index = 1,
            results = jsonb_build_array(jsonb_build_object('step_id', steps.id, 'choice', entries.choice, 'survived', entries.survived))
        FROM game_survival_event_steps AS steps
        WHERE steps.game_survival_event_id = entries.game_survival_event_id AND steps.position = 1
      SQL
    end
  end

  def down
    remove_check_constraint :game_survival_event_entries, name: 'game_survival_event_entries_current_step_check'
    remove_check_constraint :game_survival_event_entries, name: 'game_survival_event_entries_status_check'
    remove_index :game_survival_event_entries, :status
    remove_column :game_survival_event_entries, :results
    remove_column :game_survival_event_entries, :status
    remove_column :game_survival_event_entries, :current_step_index
    change_column_default :game_survival_events, :survival_choice, from: 0, to: nil
    drop_table :game_survival_event_steps
  end
end
