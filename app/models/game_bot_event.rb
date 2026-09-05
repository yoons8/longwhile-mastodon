# frozen_string_literal: true

# == Schema Information
#
# Table name: game_bot_events
#
#  id         :bigint(8)        not null, primary key
#  command    :string           not null
#  response   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#  status_id  :string           not null
#
class GameBotEvent < ApplicationRecord
  belongs_to :account

  validates :status_id, :command, presence: true
  validates :status_id, uniqueness: true
end
