# frozen_string_literal: true

# == Schema Information
#
# Table name: game_survival_event_rewards
#
#  id                     :bigint(8)        not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  game_item_id           :bigint(8)        not null
#  game_survival_event_id :bigint(8)        not null
#
class GameSurvivalEventReward < ApplicationRecord
  belongs_to :game_survival_event, inverse_of: :reward_links
  belongs_to :game_item

  validates :game_item_id, uniqueness: { scope: :game_survival_event_id }
end
