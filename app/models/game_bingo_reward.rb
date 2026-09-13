# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_rewards
#
#  id                  :bigint(8)        not null, primary key
#  bingo_count         :integer          not null
#  currency            :bigint(8)        default(0), not null
#  item_quantity       :integer          default(0), not null
#  reputation          :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  game_bingo_event_id :bigint(8)        not null
#  game_item_id        :bigint(8)
#
class GameBingoReward < ApplicationRecord
  belongs_to :game_bingo_event, inverse_of: :rewards
  belongs_to :game_item, optional: true
  has_many :grants, class_name: 'GameBingoRewardGrant', dependent: :restrict_with_error, inverse_of: :game_bingo_reward

  validates :bingo_count, numericality: { only_integer: true, in: 1..8 }, uniqueness: { scope: :game_bingo_event_id }
  validates :item_quantity, :currency, :reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :item_matches_quantity

  def summary
    Game::BingoRewardFormatter.call(game_item, item_quantity, currency, reputation)
  end

  private

  def item_matches_quantity
    errors.add(:item_quantity, '은(는) 보상 아이템을 선택했을 때 1개 이상이어야 합니다.') if game_item.present? && !item_quantity.positive?
    errors.add(:game_item, '을(를) 선택해 주세요.') if game_item.nil? && item_quantity.positive?
  end
end
