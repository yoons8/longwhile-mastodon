# frozen_string_literal: true

# == Schema Information
#
# Table name: game_items
#
#  id                 :bigint(8)        not null, primary key
#  active             :boolean          default(TRUE), not null
#  base_price         :bigint(8)        not null
#  battle_action      :string
#  consumable         :boolean          default(FALSE), not null
#  description        :text             default(""), not null
#  dice_count         :integer
#  dice_sides         :integer
#  flat_bonus         :integer          default(0), not null
#  image_content_type :string
#  image_file_name    :string
#  image_file_size    :integer
#  image_updated_at   :datetime
#  item_type          :string           not null
#  min_reputation     :integer          default(0), not null
#  name               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class GameItem < ApplicationRecord
  include Attachmentable

  before_validation :normalize_battle_attributes

  IMAGE_LIMIT = 5.megabytes
  IMAGE_MIME_TYPES = %w(image/jpeg image/png image/gif image/webp).freeze
  ITEM_TYPES = %w(battle roleplay miscellaneous).freeze
  BATTLE_ACTIONS = %w(attack defense).freeze

  has_many :game_inventories, dependent: :restrict_with_error
  has_many :game_shop_items, dependent: :restrict_with_error

  has_attached_file :image, styles: { small: { geometry: '160x160>', file_geometry_parser: FastGeometryParser } }, convert_options: { all: '-coalesce +profile "!icc,*" +set date:modify +set date:create +set date:timestamp' }, processors: [:lazy_thumbnail, :type_corrector]

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validates :base_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_reputation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :battle_action, inclusion: { in: BATTLE_ACTIONS }, allow_nil: true
  validates :dice_count, numericality: { only_integer: true, in: 1..10 }, allow_nil: true
  validates :dice_sides, numericality: { only_integer: true, in: 2..100 }, allow_nil: true
  validates :flat_bonus, numericality: { only_integer: true, in: -100..100 }
  validate :battle_effect_is_consistent
  validates_attachment :image, content_type: { content_type: IMAGE_MIME_TYPES }, size: { less_than: IMAGE_LIMIT }

  scope :active, -> { where(active: true) }
  scope :visible_to, ->(reputation) { active.where(game_items: { min_reputation: ..reputation }) }

  private

  def battle_effect_is_consistent
    errors.add(:dice_count, '와 주사위 면수는 함께 설정해야 합니다.') if dice_count.nil? != dice_sides.nil?
    return if item_type == 'battle' || ([battle_action, dice_count, dice_sides].all?(&:nil?) && flat_bonus.zero?)

    errors.add(:battle_action, '은(는) 전투 아이템에만 설정할 수 있습니다.')
  end

  def normalize_battle_attributes
    self.battle_action = nil if battle_action.blank?
  end
end
