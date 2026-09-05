# frozen_string_literal: true

class ValidateGameItemBattleConstraints < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :game_items, name: 'game_items_battle_action_check'
    validate_check_constraint :game_items, name: 'game_items_dice_count_check'
    validate_check_constraint :game_items, name: 'game_items_dice_sides_check'
  end
end
