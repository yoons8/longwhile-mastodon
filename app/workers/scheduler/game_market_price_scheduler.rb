# frozen_string_literal: true

class Scheduler::GameMarketPriceScheduler
  include Sidekiq::Worker

  sidekiq_options retry: 3, lock: :until_executed

  def perform
    Game::MarketPriceService.refresh_all!
  end
end
