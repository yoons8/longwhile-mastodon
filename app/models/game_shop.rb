# frozen_string_literal: true

# == Schema Information
#
# Table name: game_shops
#
#  id             :bigint(8)        not null, primary key
#  active         :boolean          default(TRUE), not null
#  description    :text             default(""), not null
#  ends_at        :datetime
#  min_reputation :integer          default(0), not null
#  name           :string           not null
#  shop_type      :string           default("normal"), not null
#  starts_at      :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class GameShop < ApplicationRecord
  SHOP_TYPES = %w[normal secret event].freeze

  has_many :game_shop_items, dependent: :destroy
  has_many :game_items, through: :game_shop_items

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validates :shop_type, inclusion: { in: SHOP_TYPES }
  validates :min_reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :ends_after_starts

  scope :active, -> { where(active: true) }
  scope :available_at, ->(time) { where('starts_at IS NULL OR starts_at <= ?', time).where('ends_at IS NULL OR ends_at >= ?', time) }
  scope :visible_to, ->(reputation) { active.available_at(Time.current).where('min_reputation <= ?', reputation) }

  def available_to?(profile, at: Time.current)
    active? && min_reputation <= profile.reputation && (starts_at.nil? || starts_at <= at) && (ends_at.nil? || ends_at >= at)
  end

  private

  def ends_after_starts
    errors.add(:ends_at, :greater_than, count: starts_at) if starts_at.present? && ends_at.present? && ends_at <= starts_at
  end
end
