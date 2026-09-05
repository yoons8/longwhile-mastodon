# frozen_string_literal: true

# == Schema Information
#
# Table name: game_transactions
#
#  id              :bigint(8)        not null, primary key
#  action_type     :string           not null
#  currency_change :bigint(8)        default(0), not null
#  item_change     :integer          default(0), not null
#  created_at      :datetime         not null
#  account_id      :bigint(8)        not null
#  game_item_id    :bigint(8)
#
class GameTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :game_item, optional: true

  validates :action_type, presence: true, length: { maximum: 100 }
  validates :currency_change, :item_change, numericality: { only_integer: true }
end
