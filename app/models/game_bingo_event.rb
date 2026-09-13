# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bingo_events
#
#  id          :bigint(8)        not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text             default(""), not null
#  ends_at     :datetime
#  starts_at   :datetime
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class GameBingoEvent < ApplicationRecord
  has_many :items, class_name: 'GameBingoItem', dependent: :destroy, inverse_of: :game_bingo_event
  has_many :boards, class_name: 'GameBingoBoard', dependent: :destroy, inverse_of: :game_bingo_event
  has_many :rewards, class_name: 'GameBingoReward', dependent: :destroy, inverse_of: :game_bingo_event

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validate :ends_after_starts

  scope :active, -> { where(active: true) }
  scope :available_at, ->(time) { where('starts_at IS NULL OR starts_at <= ?', time).where('ends_at IS NULL OR ends_at >= ?', time) }

  def available?(at: Time.current)
    active? && (starts_at.nil? || starts_at <= at) && (ends_at.nil? || ends_at >= at)
  end

  def admin_status(at: Time.current)
    return [:inactive, '비활성'] unless active?
    return [:scheduled, '예정'] if starts_at.present? && starts_at > at
    return [:ended, '종료'] if ends_at.present? && ends_at < at

    [:active, '진행 중']
  end

  def configured?
    items.count(&:active?) >= 9
  end

  private

  def ends_after_starts
    errors.add(:ends_at, '시작 시각보다 뒤여야 합니다.') if starts_at.present? && ends_at.present? && ends_at <= starts_at
  end
end
