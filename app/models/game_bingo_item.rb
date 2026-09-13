# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_items
#
#  id                   :bigint(8)        not null, primary key
#  active               :boolean          default(TRUE), not null
#  description          :text             default(""), not null
#  reward_currency      :bigint(8)        default(0), not null
#  reward_item_quantity :integer          default(0), not null
#  reward_reputation    :integer          default(0), not null
#  title                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  game_bingo_event_id  :bigint(8)        not null
#  reward_game_item_id  :bigint(8)
#
class GameBingoItem < ApplicationRecord
  belongs_to :game_bingo_event, inverse_of: :items
  belongs_to :reward_game_item, class_name: 'GameItem', optional: true
  has_many :submissions, class_name: 'GameBingoSubmission', dependent: :restrict_with_error, inverse_of: :game_bingo_item

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :reward_item_quantity, :reward_currency, :reward_reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :reward_item_matches_quantity

  scope :active, -> { where(active: true) }

  def reward_summary
    Game::BingoRewardFormatter.call(reward_game_item, reward_item_quantity, reward_currency, reward_reputation)
  end

  private

  def reward_item_matches_quantity
    errors.add(:reward_item_quantity, '은(는) 보상 아이템을 선택했을 때 1개 이상이어야 합니다.') if reward_game_item.present? && !reward_item_quantity.positive?
    errors.add(:reward_game_item, '을(를) 선택해 주세요.') if reward_game_item.nil? && reward_item_quantity.positive?
  end
end
