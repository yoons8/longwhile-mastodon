# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_submissions
#
#  id                   :bigint(8)        not null, primary key
#  reward_currency      :bigint(8)        default(0), not null
#  reward_item_quantity :integer          default(0), not null
#  reward_reputation    :integer          default(0), not null
#  rewarded_at          :datetime
#  url                  :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  game_bingo_board_id  :bigint(8)        not null
#  game_bingo_item_id   :bigint(8)        not null
#  reward_game_item_id  :bigint(8)
#
class GameBingoSubmission < ApplicationRecord
  belongs_to :game_bingo_board, inverse_of: :submissions
  belongs_to :game_bingo_item, inverse_of: :submissions
  belongs_to :reward_game_item, class_name: 'GameItem', optional: true

  validates :game_bingo_item_id, uniqueness: { scope: :game_bingo_board_id }
  validate :valid_http_url

  def reward_summary
    Game::BingoRewardFormatter.call(reward_game_item, reward_item_quantity, reward_currency, reward_reputation)
  end

  private

  def valid_http_url
    parsed = URI.parse(url.to_s)
    errors.add(:url, 'http 또는 https 링크를 입력해 주세요.') unless parsed.is_a?(URI::HTTP) && parsed.host.present?
  rescue URI::InvalidURIError
    errors.add(:url, '올바른 링크를 입력해 주세요.')
  end
end
