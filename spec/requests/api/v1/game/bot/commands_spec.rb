# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/game/bot/commands' do
  let(:bot) { Fabricate(:account, username: 'battle_bot') }
  let(:opponent) { Fabricate(:account, username: 'opponent') }
  let(:actor) { Fabricate(:account, username: 'challenger') }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: bot.user.id, scopes: 'read:statuses') }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }
  let(:status) do
    Fabricate(:status, account: actor, text: '@opponent @battle_bot [전투]').tap do |record|
      Mention.create!(status: record, account: opponent)
      Mention.create!(status: record, account: bot)
    end
  end

  it 'processes a bot-mentioned status using the authenticated bot account' do
    post '/api/v1/game/bot/commands', params: { status_id: status.id }, headers: headers

    expect(response).to have_http_status(200)
    expect(response.parsed_body[:text]).to include('전투를 신청')
    expect(GameBattle.last).to have_attributes(challenger_account: actor, opponent_account: opponent)
  end

  it 'rejects an access token owned by a non-bot account' do
    other = Fabricate(:account, username: 'not_the_bot')
    other_token = Fabricate(:accessible_access_token, resource_owner_id: other.user.id, scopes: 'read:statuses')

    post '/api/v1/game/bot/commands', params: { status_id: status.id }, headers: { 'Authorization' => "Bearer #{other_token.token}" }

    expect(response).to have_http_status(403)
    expect(GameBattle.count).to eq(0)
  end
end
