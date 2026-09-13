# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_reward_grants
#
#  id                   :bigint(8)        not null, primary key
#  bingo_count          :integer          not null
#  currency             :bigint(8)        default(0), not null
#  item_quantity        :integer          default(0), not null
#  reputation           :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  game_bingo_board_id  :bigint(8)        not null
#  game_bingo_reward_id :bigint(8)        not null
#  game_item_id         :bigint(8)
#
class GameBingoRewardGrant < ApplicationRecord
  belongs_to :game_bingo_board, inverse_of: :reward_grants
  belongs_to :game_bingo_reward, inverse_of: :grants
  belongs_to :game_item, optional: true

  validates :game_bingo_reward_id, uniqueness: { scope: :game_bingo_board_id }

  def summary
    Game::BingoRewardFormatter.call(game_item, item_quantity, currency, reputation)
  end
end
