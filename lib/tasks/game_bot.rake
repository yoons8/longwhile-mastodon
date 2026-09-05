# frozen_string_literal: true

namespace :game do
  namespace :bot do
    desc 'Create or print the OAuth token for the local battle bot account'
    task token: :environment do
      account = Account.find_local(ENV.fetch('GAME_BOT_ACCOUNT_USERNAME', 'battle_bot'))
      abort 'Create the local battle_bot account first.' unless account&.user

      application = Doorkeeper::Application.find_or_create_by!(name: 'Battle Bot') do |app|
        app.redirect_uri = Doorkeeper.configuration.native_redirect_uri
        app.scopes = 'read:accounts read:notifications read:statuses write:statuses'
        domain = ENV.fetch('LOCAL_DOMAIN', 'localhost')
        app.website = domain.match?(%r{\Ahttps?://}) ? domain : "http://#{domain}"
      end
      scopes = 'read:accounts read:notifications read:statuses write:statuses'
      token = Doorkeeper::AccessToken.where(application: application, resource_owner_id: account.user.id, revoked_at: nil).first_or_create!(scopes: scopes)
      token.update!(scopes: scopes) unless token.scopes.to_s == scopes

      puts token.token
    end
  end
end
