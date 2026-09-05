# frozen_string_literal: true

# == Schema Information
#
# Table name: game_battle_turns
#
#  id                   :bigint(8)        not null, primary key
#  challenger_action    :string
#  opponent_action      :string
#  resolved_at          :datetime
#  result               :jsonb            not null
#  turn_number          :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  challenger_item_id   :bigint(8)
#  challenger_status_id :string
#  game_battle_id       :bigint(8)        not null
#  opponent_item_id     :bigint(8)
#  opponent_status_id   :string
#
class GameBattleTurn < ApplicationRecord
  ACTIONS = %w(attack defense).freeze

  belongs_to :game_battle
  belongs_to :challenger_item, class_name: 'GameItem', optional: true
  belongs_to :opponent_item, class_name: 'GameItem', optional: true

  validates :turn_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :game_battle_id }
  validates :challenger_action, :opponent_action, inclusion: { in: ACTIONS }, allow_nil: true
end
