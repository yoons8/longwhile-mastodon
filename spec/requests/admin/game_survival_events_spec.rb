# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin game survival events' do
  it 'rejects a regular user' do
    sign_in Fabricate(:user)

    get admin_game_survival_events_path

    expect(response).to have_http_status(403)
  end

  it 'allows an administrator to create an event' do
    sign_in Fabricate(:admin_user)
    items = Array.new(7) { |index| GameItem.create!(name: "보상 #{index}", base_price: 0, item_type: 'miscellaneous') }

    expect do
      post admin_game_survival_events_path, params: {
        game_survival_event: {
          title: '숲에서 살아남기',
          description: '안전한 길을 고르세요.',
          failure_messages: Array.new(7) { |index| "탈락 #{index}" },
          reward_item_ids: items.map(&:id),
          active: true,
        },
      }
    end.to change(GameSurvivalEvent, :count).by(1)

    expect(response).to redirect_to(admin_game_survival_event_steps_path(GameSurvivalEvent.last))
  end
end
