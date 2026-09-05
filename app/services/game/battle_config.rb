# frozen_string_literal: true

module Game
  class BattleConfig
    class << self
      def fetch(key)
        config.fetch(key.to_sym)
      end

      def message(key, **values)
        format(config.fetch(:messages).fetch(key.to_sym), values)
      end

      private

      def config
        @config ||= Rails.application.config_for(:game_battle)
      end
    end
  end
end
