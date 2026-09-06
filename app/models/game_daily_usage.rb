# frozen_string_literal: true

# == Schema Information
#
# Table name: game_daily_usages
#
#  id          :bigint(8)        not null, primary key
#  action_type :string           not null
#  count       :integer          default(0), not null
#  usage_date  :date             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint(8)        not null
#
class GameDailyUsage < ApplicationRecord
  belongs_to :account

  validates :action_type, presence: true, length: { maximum: 100 }, uniqueness: { scope: [:account_id, :action_type, :usage_date] }
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
