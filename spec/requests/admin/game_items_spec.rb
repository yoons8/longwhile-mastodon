# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin game items' do
  describe 'GET /admin/game_items' do
    it 'rejects a regular user' do
      sign_in Fabricate(:user)

      get admin_game_items_path

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows an existing Mastodon administrator' do
      sign_in Fabricate(:admin_user)

      get admin_game_items_path

      expect(response).to have_http_status(:success)
    end
  end
end
