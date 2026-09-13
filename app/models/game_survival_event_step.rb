# frozen_string_literal: true

# == Schema Information
#
# Table name: game_survival_event_steps
#
#  id                     :bigint(8)        not null, primary key
#  choices                :jsonb            not null
#  description            :text             default(""), not null
#  position               :integer          not null
#  survival_choice        :integer          not null
#  title                  :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  game_survival_event_id :bigint(8)        not null
#
class GameSurvivalEventStep < ApplicationRecord
  belongs_to :game_survival_event, inverse_of: :steps

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, uniqueness: { scope: :game_survival_event_id }
  validates :survival_choice, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
  validate :exactly_three_choices

  private

  def exactly_three_choices
    normalized = Array(choices).map { |choice| choice.to_s.strip }
    errors.add(:choices, '선택지는 비어 있지 않은 3개여야 합니다.') unless normalized.size == 3 && normalized.all?(&:present?)
  end
end
