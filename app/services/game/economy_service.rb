# frozen_string_literal: true

module Game
  class EconomyService
    SHELL_GAMES_PER_DAY = 3
    SALE_RATE = 0.5
    TALK_CURRENCY = 10
    TALK_REPUTATION = 1

    def initialize(account)
      @account = account
    end

    def purchase!(game_item_id)
      with_locked_profile do |profile|
        item = GameItem.lock.find(game_item_id)
        raise Error.new(:unavailable, '구매할 수 없는 아이템입니다.') unless item.active? && item.min_reputation <= profile.reputation

        raise Error.new(:insufficient_currency, '재화가 부족합니다.') if profile.currency < item.base_price

        profile.update!(currency: profile.currency - item.base_price)
        change_inventory!(item, 1)
        record!(action_type: 'purchase', item: item, currency: -item.base_price, quantity: 1)

        { currency: profile.currency, item: item.name, quantity: 1 }
      end
    end

    def sell!(game_item_id, quantity)
      quantity = strict_positive_integer(quantity)

      with_locked_profile do |profile|
        item = GameItem.find(game_item_id)
        inventory = GameInventory.lock.find_by(account: @account, game_item: item)
        raise Error.new(:not_owned, '판매할 아이템이 부족합니다.') if inventory.nil? || inventory.quantity < quantity

        proceeds = (item.base_price * SALE_RATE).floor * quantity
        inventory.update!(quantity: inventory.quantity - quantity)
        profile.update!(currency: profile.currency + proceeds)
        record!(action_type: 'sale', item: item, currency: proceeds, quantity: -quantity)
        { currency: profile.currency, item: item.name, quantity: quantity, proceeds: proceeds }
      end
    end

    def talk!
      with_locked_profile do |profile|
        use_daily!(profile, 'talk', 1)
        profile.update!(currency: profile.currency + TALK_CURRENCY, reputation: profile.reputation + TALK_REPUTATION)
        record!(action_type: 'talk', currency: TALK_CURRENCY)

        { currency: profile.currency, reputation: profile.reputation, dialogue: dialogue_for(profile.reputation) }
      end
    end

    def vend!
      with_locked_profile do |profile|
        use_daily!(profile, 'vending', 1)
        scope = GameItem.visible_to(profile.reputation)
        count = scope.count
        raise Error.new(:unavailable, '자판기에 아이템이 없습니다.') if count.zero?

        item = scope.offset(SecureRandom.random_number(count)).first!
        change_inventory!(item, 1)
        record!(action_type: 'vending', item: item, quantity: 1)
        { item: item.name, currency: profile.currency }
      end
    end

    def shell_game!(bet, cup)
      bet = strict_positive_integer(bet)
      cup = Integer(cup, exception: false)
      raise Error.new(:invalid_cup, '컵은 1부터 3까지 선택해야 합니다.') unless (1..3).cover?(cup)

      with_locked_profile do |profile|
        use_daily!(profile, 'shell_game', SHELL_GAMES_PER_DAY)
        raise Error.new(:insufficient_currency, '재화가 부족합니다.') if bet > profile.currency

        answer = SecureRandom.random_number(3) + 1
        won = cup == answer
        change = won ? bet : -bet
        profile.update!(currency: profile.currency + change)
        record!(action_type: 'shell_game', currency: change)
        { won: won, answer: answer, currency_change: change, currency: profile.currency }
      end
    end

    private

    def profile
      GameProfile.create_or_find_by!(account: @account)
    end

    def with_locked_profile(&block)
      GameProfile.transaction { profile.lock! && yield(profile) }
    end

    def use_daily!(profile, action_type, limit)
      usage = GameDailyUsage.find_or_create_by!(account: @account, action_type: action_type, usage_date: Time.zone.today)
      usage.lock!
      raise Error.new(:daily_limit, '오늘 이용 횟수를 모두 사용했습니다.') if usage.count >= limit

      usage.increment!(:count)
    end

    def change_inventory!(item, amount)
      inventory = GameInventory.create_or_find_by!(account: @account, game_item: item)
      inventory.lock!
      inventory.update!(quantity: inventory.quantity + amount)
    end

    def record!(action_type:, item: nil, currency: 0, quantity: 0)
      GameTransaction.create!(account: @account, action_type: action_type, game_item: item, currency_change: currency, item_change: quantity)
    end

    def strict_positive_integer(value)
      number = Integer(value, exception: false)
      raise Error.new(:invalid_quantity, '수량 또는 배팅액은 양의 정수여야 합니다.') unless number&.positive?

      number
    end

    def dialogue_for(reputation)
      return '당신이라면 특별한 물건도 맡길 수 있겠군요.' if reputation >= 50
      return '이제 제법 낯이 익군요. 좋은 물건이 들어오면 알려드리죠.' if reputation >= 20
      return '또 오셨군요. 천천히 둘러보세요.' if reputation >= 5

      '처음 뵙는군요. 필요한 물건이 있습니까?'
    end
  end
end
