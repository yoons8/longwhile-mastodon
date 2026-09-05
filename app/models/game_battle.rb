# frozen_string_literal: true

# == Schema Information
#
# Table name: game_battles
#
#  id                    :bigint(8)        not null, primary key
#  challenger_hp         :integer          not null
#  current_turn          :integer          default(0), not null
#  finished_at           :datetime
#  kill_used_at          :datetime
#  opponent_hp           :integer          not null
#  revenge_used_at       :datetime
#  state                 :string           default("pending"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  challenger_account_id :bigint(8)        not null
#  loser_account_id      :bigint(8)
#  opponent_account_id   :bigint(8)        not null
#  revenge_of_id         :bigint(8)
#  winner_account_id     :bigint(8)
#
class GameBattle < ApplicationRecord
  STATES = %w(pending active finished cancelled rejected).freeze
  OPEN_STATES = %w(pending active).freeze

  belongs_to :challenger_account, class_name: 'Account'
  belongs_to :opponent_account, class_name: 'Account'
  belongs_to :winner_account, class_name: 'Account', optional: true
  belongs_to :loser_account, class_name: 'Account', optional: true
  belongs_to :revenge_of, class_name: 'GameBattle', optional: true
  has_many :turns, class_name: 'GameBattleTurn', dependent: :destroy

  validates :state, inclusion: { in: STATES }
  validates :current_turn, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :challenger_hp, :opponent_hp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :participants_are_distinct

  scope :open, -> { where(state: OPEN_STATES) }
  scope :involving, ->(account) { where(challenger_account: account).or(where(opponent_account: account)) }

  def participant?(account)
    challenger_account_id == account.id || opponent_account_id == account.id
  end

  def opponent_for(account)
    challenger_account_id == account.id ? opponent_account : challenger_account
  end

  private

  def participants_are_distinct
    errors.add(:opponent_account, :invalid) if challenger_account_id == opponent_account_id
  end
end
