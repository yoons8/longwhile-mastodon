# frozen_string_literal: true

module Game
  class BlackjackService
    TTL = 10.minutes.to_i
    GAMES_PER_DAY = 3
    DEALER_STAND_TOTAL = 17
    RANKS = %w(A 2 3 4 5 6 7 8 9 10 J Q K).freeze
    SUITS = %w(♠ ♥ ♦ ♣).freeze
    FACE_RANKS = %w(10 J Q K).freeze
    CONSUME_SCRIPT = <<~LUA.squish.freeze
      local value = redis.call('get', KEYS[1])
      if value then redis.call('del', KEYS[1]) end
      return value
    LUA

    def initialize(account)
      @account = account
    end

    def start!(bet)
      bet = strict_positive_integer(bet)

      GameProfile.transaction do
        profile = GameProfile.create_or_find_by!(account: @account)
        profile.lock!
        raise Error.new(:game_in_progress, '진행 중인 블랙잭 게임을 먼저 마무리하세요.') if active?

        raise Error.new(:insufficient_currency, '재화가 부족합니다.') if profile.currency < bet
        use_daily!

        profile.update!(currency: profile.currency - bet)
        record!(action_type: 'blackjack_bet', currency: -bet)
        state = new_state(bet)

        if blackjack?(state.fetch(:player)) || blackjack?(state.fetch(:dealer))
          settle_with_profile!(profile, state, compare_hands(state), '블랙잭!')
        else
          write!(state)
          public_state(state).merge(currency: profile.currency)
        end
      end
    end

    def state
      raw = RedisConnection.with { |redis| redis.get(key) }
      return if raw.nil?

      public_state(JSON.parse(raw, symbolize_names: true))
    end

    def hit!(token)
      state = consume!(token)
      draw!(state, :player)

      return resolve!(state, :lose, '버스트! 딜러의 승리입니다.') if hand_total(state.fetch(:player)) > 21
      return resolve_dealer!(state) if hand_total(state.fetch(:player)) == 21

      write!(state)
      public_state(state)
    end

    def stand!(token)
      resolve_dealer!(consume!(token))
    end

    private

    def key
      "game:blackjack:account:#{@account.id}"
    end

    def active?
      RedisConnection.with { |redis| redis.exists?(key) }
    end

    def new_state(bet)
      deck = deck_for.shuffle(random: Random.new)
      {
        token: SecureRandom.hex(24),
        bet: bet,
        deck: deck,
        player: [deck.pop, deck.pop],
        dealer: [deck.pop, deck.pop],
      }
    end

    def deck_for
      RANKS.flat_map do |rank|
        SUITS.map { |suit| { rank: rank, suit: suit } }
      end
    end

    def draw!(state, hand)
      state.fetch(hand) << state.fetch(:deck).pop
    end

    def blackjack?(hand)
      hand.length == 2 && hand_total(hand) == 21
    end

    def hand_total(hand)
      total = hand.sum { |card| card_value(card) }
      aces = hand.count { |card| card.fetch(:rank, card['rank']) == 'A' }
      total -= 10 while total > 21 && aces.positive? && (aces -= 1)
      total
    end

    def card_value(card)
      rank = card.fetch(:rank, card['rank'])
      return 11 if rank == 'A'
      return 10 if FACE_RANKS.include?(rank)

      rank.to_i
    end

    def resolve_dealer!(state)
      draw!(state, :dealer) while hand_total(state.fetch(:dealer)) < DEALER_STAND_TOTAL
      resolve!(state, compare_hands(state), nil)
    end

    def compare_hands(state)
      player_total = hand_total(state.fetch(:player))
      dealer_total = hand_total(state.fetch(:dealer))
      return :win if dealer_total > 21 || player_total > dealer_total
      return :lose if player_total < dealer_total

      :push
    end

    def resolve!(state, outcome, message)
      GameProfile.transaction do
        profile = GameProfile.create_or_find_by!(account: @account)
        profile.lock!
        settle_with_profile!(profile, state, outcome, message)
      end
    end

    def settle_with_profile!(profile, state, outcome, message)
      payout = case outcome
               when :win then state.fetch(:bet) * 2
               when :push then state.fetch(:bet)
               else 0
               end
      profile.update!(currency: profile.currency + payout) if payout.positive?
      record!(action_type: "blackjack_#{outcome}", currency: payout) if payout.positive?

      finished_state(state, outcome, message, profile.currency, payout)
    end

    def finished_state(state, outcome, message, currency, payout)
      {
        finished: true,
        outcome: outcome,
        message: message || outcome_message(outcome),
        bet: state.fetch(:bet),
        player_cards: state.fetch(:player),
        dealer_cards: state.fetch(:dealer),
        player_total: hand_total(state.fetch(:player)),
        dealer_total: hand_total(state.fetch(:dealer)),
        payout: payout,
        currency: currency,
      }
    end

    def outcome_message(outcome)
      { win: '승리! 배팅액의 두 배를 받았습니다.', lose: '패배했습니다.', push: '무승부입니다. 배팅액을 돌려받았습니다.' }.fetch(outcome)
    end

    def public_state(state)
      {
        token: state.fetch(:token),
        bet: state.fetch(:bet),
        player_cards: state.fetch(:player),
        dealer_cards: [state.fetch(:dealer).first],
        player_total: hand_total(state.fetch(:player)),
        can_hit: true,
        expires_in: TTL,
      }
    end

    def write!(state)
      RedisConnection.with { |redis| redis.set(key, state.to_json, ex: TTL) }
    end

    def consume!(token)
      raw = RedisConnection.with { |redis| redis.eval(CONSUME_SCRIPT, keys: [key]) }
      state = JSON.parse(raw, symbolize_names: true) if raw
      raise Error.new(:expired, '게임 세션이 만료되었습니다. 다시 시작하세요.') if state.nil?
      raise Error.new(:invalid_session, '유효하지 않은 블랙잭 게임입니다.') unless ActiveSupport::SecurityUtils.secure_compare(state.fetch(:token), token.to_s)

      state
    end

    def use_daily!
      usage = GameDailyUsage.find_or_create_by!(account: @account, action_type: 'blackjack', usage_date: Time.zone.today)
      usage.lock!
      raise Error.new(:daily_limit, '오늘 블랙잭 이용 횟수를 모두 사용했습니다.') if usage.count >= GAMES_PER_DAY

      usage.increment!(:count)
    end

    def record!(action_type:, currency: 0)
      GameTransaction.create!(account: @account, action_type: action_type, currency_change: currency, item_change: 0)
    end

    def strict_positive_integer(value)
      number = Integer(value, exception: false)
      raise Error.new(:invalid_bet, '배팅액은 양의 정수여야 합니다.') unless number&.positive?

      number
    end
  end
end
