# frozen_string_literal: true

# == Schema Information
#
# Table name: game_survival_events
#
#  id                            :bigint(8)        not null, primary key
#  active                        :boolean          default(TRUE), not null
#  background_image_content_type :string
#  background_image_file_name    :string
#  background_image_file_size    :integer
#  background_image_updated_at   :datetime
#  choices                       :jsonb            not null
#  description                   :text             default(""), not null
#  ends_at                       :datetime
#  failure_messages              :jsonb            not null
#  starts_at                     :datetime
#  survival_choice               :integer          default(0), not null
#  title                         :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
class GameSurvivalEvent < ApplicationRecord
  include Attachmentable

  BACKGROUND_IMAGE_LIMIT = 8.megabytes
  BACKGROUND_IMAGE_MIME_TYPES = %w(image/jpeg image/png image/webp).freeze

  attr_accessor :remove_background_image

  before_validation :clear_background_image, if: -> { ActiveModel::Type::Boolean.new.cast(remove_background_image) }

  has_many :entries, class_name: 'GameSurvivalEventEntry', dependent: :destroy, inverse_of: :game_survival_event
  has_many :steps, -> { order(:position) }, class_name: 'GameSurvivalEventStep', dependent: :destroy, inverse_of: :game_survival_event
  has_many :reward_links, class_name: 'GameSurvivalEventReward', dependent: :destroy, inverse_of: :game_survival_event
  has_many :reward_items, through: :reward_links, source: :game_item

  has_attached_file :background_image, styles: { wide: { geometry: '1200x600#', file_geometry_parser: FastGeometryParser } }, convert_options: { all: '-coalesce +profile "!icc,*" +set date:modify +set date:create +set date:timestamp' }, processors: [:lazy_thumbnail, :type_corrector]

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validate :seven_or_eight_failure_messages
  validate :seven_or_eight_reward_items
  validate :ends_after_starts
  validates_attachment :background_image, content_type: { content_type: BACKGROUND_IMAGE_MIME_TYPES }, size: { less_than: BACKGROUND_IMAGE_LIMIT }

  scope :active, -> { where(active: true) }
  scope :available_at, ->(time) { where('starts_at IS NULL OR starts_at <= ?', time).where('ends_at IS NULL OR ends_at >= ?', time) }

  def available?(at: Time.current)
    active? && (starts_at.nil? || starts_at <= at) && (ends_at.nil? || ends_at >= at)
  end

  def ready?
    steps.exists? && normalized_failure_messages.size.between?(7, 8) && reward_items.size.between?(7, 8)
  end

  def normalized_failure_messages
    Array(failure_messages).map { |message| message.to_s.strip }.compact_blank
  end

  private

  def clear_background_image
    background_image.clear
  end

  def ends_after_starts
    errors.add(:ends_at, '시작 시각보다 뒤여야 합니다.') if starts_at.present? && ends_at.present? && ends_at <= starts_at
  end

  def seven_or_eight_failure_messages
    errors.add(:base, '탈락 문구는 7개 또는 8개여야 합니다.') unless normalized_failure_messages.size.between?(7, 8)
  end

  def seven_or_eight_reward_items
    count = Array(reward_item_ids).compact_blank.uniq.size
    errors.add(:base, '보상 아이템은 7개 또는 8개를 선택해야 합니다.') unless count.between?(7, 8)
  end
end
