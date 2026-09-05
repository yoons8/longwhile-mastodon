# frozen_string_literal: true

# == Schema Information
#
# Table name: game_inventories
#
#  id           :bigint(8)        not null, primary key
#  quantity     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint(8)        not null
#  game_item_id :bigint(8)        not null
#
class GameInventory < ApplicationRecord
  belongs_to :account
  belongs_to :game_item

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :owned, -> { where('quantity > 0') }
end
