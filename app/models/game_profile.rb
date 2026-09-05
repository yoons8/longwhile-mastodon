# frozen_string_literal: true

# == Schema Information
#
# Table name: game_profiles
#
#  id         :bigint(8)        not null, primary key
#  currency   :bigint(8)        default(0), not null
#  reputation :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#
class GameProfile < ApplicationRecord
  belongs_to :account

  validates :currency, :reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
