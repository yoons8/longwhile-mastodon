# frozen_string_literal: true

# == Schema Information
#
# Table name: game_shop_items
#
#  id             :bigint(8)        not null, primary key
#  active         :boolean          default(TRUE), not null
#  min_reputation :integer          default(0), not null
#  price          :bigint(8)        not null
#  purchase_limit :integer
#  stock          :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_item_id   :bigint(8)        not null
#  game_shop_id   :bigint(8)        not null
#
class GameShopItem < ApplicationRecord
  belongs_to :game_shop
  belongs_to :game_item

  validates :game_item_id, uniqueness: { scope: :game_shop_id }
  validates :price, :min_reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :purchase_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def available_to?(profile)
    active? && game_item.active? && game_item.min_reputation <= profile.reputation && min_reputation <= profile.reputation && stock != 0 && game_shop.available_to?(profile)
  end
end
