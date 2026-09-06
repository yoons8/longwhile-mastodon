# frozen_string_literal: true

module Game
  class BattleConfig
    class << self
      def fetch(key)
        config.fetch(key.to_sym)
      end

      def message(key, **values)
        template = config.fetch(:messages).fetch(key.to_sym)
        begin
          missing_keys = template.scan(/%\{([a-zA-Z_]\w*)\}/).flatten.map!(&:to_sym).uniq - values.keys

          if missing_keys.any?
            Rails.logger.error("Game battle message '#{key}' is missing values: #{missing_keys.join(', ')}")
            values = values.merge(missing_keys.to_h { |missing_key| [missing_key, "%{#{missing_key}}"] })
          end

          format(template, values)
        rescue ArgumentError, KeyError => e
          Rails.logger.error("Invalid game battle message '#{key}': #{e.message}")
          template
        end
      end

      def kill_random_phrase
        phrases = Array(config.fetch(:kill_random_phrases, [])).select(&:present?)
        return '쓰러집니다' if phrases.empty?

        phrases.fetch(SecureRandom.random_number(phrases.length))
      end

      private

      def config
        @config ||= Rails.application.config_for(:game_battle)
      end
    end
  end
end
