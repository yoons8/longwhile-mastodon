# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_items
#
#  id                  :bigint(8)        not null, primary key
#  active              :boolean          default(TRUE), not null
#  description         :text             default(""), not null
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  game_bingo_event_id :bigint(8)        not null
#
class GameBingoItem < ApplicationRecord
  belongs_to :game_bingo_event, inverse_of: :items
  has_many :submissions, class_name: 'GameBingoSubmission', dependent: :restrict_with_error, inverse_of: :game_bingo_item

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
end
