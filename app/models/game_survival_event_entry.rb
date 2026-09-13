# frozen_string_literal: true

# == Schema Information
#
# Table name: game_survival_event_entries
#
#  id                     :bigint(8)        not null, primary key
#  choice                 :integer          not null
#  current_step_index     :integer          default(0), not null
#  outcome_message        :text
#  results                :jsonb            not null
#  status                 :string           default("in_progress"), not null
#  survived               :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint(8)        not null
#  game_survival_event_id :bigint(8)        not null
#  reward_game_item_id    :bigint(8)
#
class GameSurvivalEventEntry < ApplicationRecord
  STATUSES = %w(in_progress completed eliminated).freeze

  belongs_to :game_survival_event, inverse_of: :entries
  belongs_to :account
  belongs_to :reward_game_item, class_name: 'GameItem', optional: true

  validates :account_id, uniqueness: { scope: :game_survival_event_id }
  validates :choice, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
  validates :survived, inclusion: { in: [true, false] }
  validates :current_step_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }

  def finished? = completed? || eliminated?
  def completed? = status == 'completed'
  def eliminated? = status == 'eliminated'
end
