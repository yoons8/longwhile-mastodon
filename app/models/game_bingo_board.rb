# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_boards
#
#  id                  :bigint(8)        not null, primary key
#  completed_at        :datetime
#  item_ids            :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint(8)        not null
#  game_bingo_event_id :bigint(8)        not null
#
class GameBingoBoard < ApplicationRecord
  LINES = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]].freeze

  belongs_to :game_bingo_event, inverse_of: :boards
  belongs_to :account
  has_many :submissions, class_name: 'GameBingoSubmission', dependent: :destroy, inverse_of: :game_bingo_board

  validate :nine_cells

  def bingo_count
    checked = submissions.pluck(:game_bingo_item_id).to_set
    LINES.count { |line| line.all? { |index| checked.include?(item_ids[index]) } }
  end

  private

  def nine_cells
    errors.add(:item_ids, '빙고판은 서로 다른 9개 항목으로 구성되어야 합니다.') unless item_ids.size == 9 && item_ids.uniq.size == 9
  end
end
