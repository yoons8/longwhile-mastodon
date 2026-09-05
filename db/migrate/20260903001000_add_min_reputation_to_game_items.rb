# frozen_string_literal: true

class AddMinReputationToGameItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :game_items, :min_reputation, :integer, null: false, default: 0
    add_index :game_items, [:active, :min_reputation], algorithm: :concurrently
    add_check_constraint :game_items, 'min_reputation >= 0', name: 'game_items_min_reputation_nonnegative', validate: false
    validate_check_constraint :game_items, name: 'game_items_min_reputation_nonnegative'
  end
end
