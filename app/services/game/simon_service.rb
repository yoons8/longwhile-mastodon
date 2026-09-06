# frozen_string_literal: true

module Game
  class SimonService
    TTL = 5.minutes.to_i
    GAMES_PER_DAY = 3
    MAX_ROUND = 5
    REWARD = 25
    CONSUME_SCRIPT = <<~LUA.squish.freeze
      local value = redis.call('get', KEYS[1])
      if value then redis.call('del', KEYS[1]) end
      return value
    LUA

    def initialize(account)
      @account = account
    end

    def start!
      GameProfile.transaction do
        profile = GameProfile.create_or_find_by!(account: @account)
        profile.lock!
        raise Error.new(:game_in_progress, '진행 중인 Simon 게임을 먼저 마무리하세요.') if active?

        use_daily!
        state = { token: SecureRandom.hex(24), round: 1, sequence: sequence_for(1) }
        write(state)
        public_state(state)
      end
    end

    def submit!(token, input)
      state = consume!
      raise Error.new(:expired, '게임 세션이 만료되었습니다. 다시 시작하세요.') if state.nil?
      raise Error.new(:invalid_session, '유효하지 않은 게임 세션입니다.') unless ActiveSupport::SecurityUtils.secure_compare(state.fetch('token'), token.to_s)

      submitted = Array(input).map { |value| Integer(value, exception: false) }
      unless submitted.all? { |value| (0..3).cover?(value) } && submitted == state.fetch('sequence')
        return { success: false, complete: false, round: state.fetch('round') }
      end

      if state.fetch('round') >= MAX_ROUND
        currency = reward!
        return { success: true, complete: true, reward: REWARD, currency: currency }
      end

      next_state = { token: SecureRandom.hex(24), round: state.fetch('round') + 1, sequence: sequence_for(state.fetch('round') + 1) }
      write(next_state)
      public_state(next_state).merge(success: true, complete: false)
    end

    private

    def key
      "game:simon:account:#{@account.id}"
    end

    def active?
      RedisConnection.with { |redis| redis.exists?(key) }
    end

    def write(state)
      RedisConnection.with { |redis| redis.set(key, state.to_json, ex: TTL) }
    end

    def consume!
      raw = RedisConnection.with { |redis| redis.eval(CONSUME_SCRIPT, keys: [key]) }
      JSON.parse(raw) if raw
    end

    def sequence_for(round)
      Array.new(round + 2) { SecureRandom.random_number(4) }
    end

    def public_state(state)
      state.slice(:token, :round, :sequence).merge(expires_in: TTL)
    end

    def reward!
      GameProfile.transaction do
        profile = GameProfile.create_or_find_by!(account: @account)
        profile.lock!
        profile.update!(currency: profile.currency + REWARD)
        GameTransaction.create!(account: @account, action_type: 'simon_reward', currency_change: REWARD)
        profile.currency
      end
    end

    def use_daily!
      usage = GameDailyUsage.find_or_create_by!(account: @account, action_type: 'simon', usage_date: Time.zone.today)
      usage.lock!
      raise Error.new(:daily_limit, '오늘 Simon 이용 횟수를 모두 사용했습니다.') if usage.count >= GAMES_PER_DAY

      usage.increment!(:count)
    end
  end
end
