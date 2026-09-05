# frozen_string_literal: true

module Game
  class BattleService
    COMMAND_PATTERN = %r{\[(전투포기|전투|승낙|거절|공격|방어|복수|살해|주사위|양도)(?:/([^\]]+))?\]}
    ACTIONS = { '공격' => 'attack', '방어' => 'defense' }.freeze

    def initialize(status:, bot_account:)
      @status = status
      @actor = status.account
      @bot_account = bot_account
    end

    def call
      existing = GameBotEvent.find_by(status_id: @status.id.to_s)
      return existing.response.deep_symbolize_keys if existing

      command, option = parse_command
      response = GameBotEvent.transaction do
        event = GameBotEvent.create!(status_id: @status.id.to_s, account: @actor, command: command || 'invalid')
        result = dispatch(command, option)
        event.update!(response: result)
        result
      end
      response.deep_symbolize_keys
    rescue ActiveRecord::RecordNotUnique
      GameBotEvent.find_by!(status_id: @status.id.to_s).response.deep_symbolize_keys
    end

    private

    def parse_command
      match = @status.text.to_s.match(COMMAND_PATTERN)
      [match&.[](1), match&.[](2)&.strip]
    end

    def dispatch(command, option)
      case command
      when '전투' then challenge!
      when '승낙' then accept!
      when '거절' then reject!
      when '공격', '방어' then act!(ACTIONS.fetch(command), option)
      when '전투포기' then cancel!
      when '복수' then revenge!
      when '살해' then kill!
      when '주사위' then payload(BattleConfig.message(:dice_result, result: roll(1, 6)))
      when '양도' then transfer!(option)
      else payload(BattleConfig.message(:invalid_command))
      end
    end

    def challenge!
      target = sole_target
      return payload(BattleConfig.message(:invalid_target)) unless target

      with_profile_locks(@actor, target) do
        return payload(BattleConfig.message(:already_in_battle)) if open_battle_for(@actor)
        return payload(BattleConfig.message(:target_in_battle)) if open_battle_for(target)

        hp = BattleConfig.fetch(:max_hp)
        GameBattle.create!(challenger_account: @actor, opponent_account: target, challenger_hp: hp, opponent_hp: hp)
      end
      payload(BattleConfig.message(:challenge_created, challenger: label(@actor), opponent: label(target)), accounts: [@actor, target])
    end

    def accept!
      battle = GameBattle.open.find_by(opponent_account: @actor, state: 'pending')
      return payload(BattleConfig.message(:no_battle)) unless battle

      with_battle_locks(battle) do
        battle.lock!
        return payload(BattleConfig.message(:no_battle)) unless battle.state == 'pending'

        battle.update!(state: 'active', current_turn: 1)
        battle.turns.create!(turn_number: 1)
      end
      payload(BattleConfig.message(:challenge_accepted), accounts: participants(battle))
    end

    def reject!
      battle = GameBattle.open.find_by(opponent_account: @actor, state: 'pending')
      return payload(BattleConfig.message(:no_battle)) unless battle

      with_battle_locks(battle) do
        battle.lock!
        return payload(BattleConfig.message(:no_battle)) unless battle.state == 'pending'

        profile = GameProfile.lock.find_by!(account: battle.challenger_account)
        loss = BattleConfig.fetch(:refusal_reputation_loss)
        profile.update!(reputation: [profile.reputation - loss, 0].max)
        battle.update!(state: 'rejected', finished_at: Time.current)
      end
      payload(BattleConfig.message(:challenge_rejected), accounts: participants(battle))
    end

    def act!(action, item_name)
      battle = GameBattle.where(state: 'active').involving(@actor).first
      return payload(BattleConfig.message(:no_battle)) unless battle

      response = nil
      with_battle_locks(battle) do
        battle.lock!
        return payload(BattleConfig.message(:no_battle)) unless battle.state == 'active'

        turn = battle.turns.lock.find_by!(turn_number: battle.current_turn)
        side = side_for(battle, @actor)
        awaiting_revenge_attack = battle.revenge_of_id? && turn.turn_number == 1 && side == 'opponent' && turn.challenger_action.blank?
        return payload(BattleConfig.message(:awaiting_revenge_attack), accounts: participants(battle)) if awaiting_revenge_attack

        action_column = "#{side}_action"
        return payload(BattleConfig.message(:duplicate_action)) if turn.public_send(action_column).present?

        item = find_item(item_name, action)
        turn.update!(action_column => action, "#{side}_item" => item, "#{side}_status_id" => @status.id.to_s)
        response = if turn.reload.challenger_action.present? && turn.opponent_action.present?
                     resolve_turn!(battle, turn)
                   else
                     payload(BattleConfig.message(:action_recorded, player: label(@actor), action: korean_action(action)), accounts: participants(battle))
                   end
      end
      response
    end

    def resolve_turn!(battle, turn)
      return payload(format_turn(battle, turn.result), accounts: participants(battle)) if turn.resolved_at?

      challenger = resolve_action(battle, turn, 'challenger')
      opponent = resolve_action(battle, turn, 'opponent')
      challenger_damage, opponent_damage = damages(challenger, opponent)
      challenger_hp = [battle.challenger_hp - challenger_damage, 0].max
      opponent_hp = [battle.opponent_hp - opponent_damage, 0].max
      result = {
        challenger: challenger, opponent: opponent,
        challenger_damage: challenger_damage, opponent_damage: opponent_damage,
        fallbacks: [challenger[:fallback], opponent[:fallback]].compact
      }
      turn.update!(result: result, resolved_at: Time.current)
      battle.update!(challenger_hp: challenger_hp, opponent_hp: opponent_hp)

      ending = finish_if_needed!(battle)
      details = format_turn(battle, result, turn.turn_number)
      payload([details, ending].compact.join("\n\n"), accounts: participants(battle))
    end

    def resolve_action(battle, turn, side)
      account = battle.public_send("#{side}_account")
      action = turn.public_send("#{side}_action")
      item = turn.public_send("#{side}_item")
      item_roll = 0
      fallback = nil

      if item
        inventory = GameInventory.lock.find_by(account: account, game_item: item)
        if inventory&.quantity&.positive? && valid_battle_item?(item, action)
          inventory.update!(quantity: inventory.quantity - 1)
          item_roll = roll(item.dice_count || 0, item.dice_sides || 2) + item.flat_bonus
          GameTransaction.create!(account: account, action_type: 'battle_item', game_item: item, item_change: -1)
        else
          fallback = BattleConfig.message(:item_fallback, player: label(account), item: item.name, action: korean_action(action))
        end
      end

      base = roll(BattleConfig.fetch("#{action}_dice_count"), BattleConfig.fetch("#{action}_dice_sides"))
      bonus = BattleConfig.fetch("#{action}_bonus")
      bonus += BattleConfig.fetch(:revenge_attack_bonus) if revenge_bonus?(battle, turn, account, action)
      { action: action, base_roll: base, item_roll: item_roll, total: [base + bonus + item_roll, 0].max, fallback: fallback }
    end

    def damages(challenger, opponent)
      case [challenger[:action], opponent[:action]]
      when %w(attack attack) then [opponent[:total], challenger[:total]]
      when %w(attack defense) then [0, [challenger[:total] - opponent[:total], 0].max]
      when %w(defense attack) then [[opponent[:total] - challenger[:total], 0].max, 0]
      else [0, 0]
      end
    end

    def finish_if_needed!(battle)
      max_turns = BattleConfig.fetch(:max_turns)
      return advance_turn!(battle) if battle.challenger_hp.positive? && battle.opponent_hp.positive? && battle.current_turn < max_turns

      if battle.challenger_hp == battle.opponent_hp
        battle.update!(state: 'finished', finished_at: Time.current)
        return BattleConfig.message(:battle_draw)
      end

      winner, loser = battle.challenger_hp > battle.opponent_hp ? participants(battle) : participants(battle).reverse
      settle!(battle, winner, loser)
      BattleConfig.message(:battle_won, winner: label(winner))
    end

    def advance_turn!(battle)
      next_turn = battle.current_turn + 1
      battle.update!(current_turn: next_turn)
      battle.turns.create!(turn_number: next_turn)
      nil
    end

    def settle!(battle, winner, loser)
      winner_profile = GameProfile.lock.find_by!(account: winner)
      loser_profile = GameProfile.lock.find_by!(account: loser)
      winner_currency = BattleConfig.fetch(:winner_currency)
      winner_reputation = BattleConfig.fetch(:winner_reputation)
      loser_currency = BattleConfig.fetch(:loser_currency)
      loser_loss = BattleConfig.fetch(:loser_reputation_loss)
      winner_profile.update!(currency: winner_profile.currency + winner_currency, reputation: winner_profile.reputation + winner_reputation)
      loser_profile.update!(currency: loser_profile.currency + loser_currency, reputation: [loser_profile.reputation - loser_loss, 0].max)
      battle.update!(state: 'finished', winner_account: winner, loser_account: loser, finished_at: Time.current)
      GameTransaction.create!(account: winner, action_type: 'battle_win', currency_change: winner_currency)
      GameTransaction.create!(account: loser, action_type: 'battle_loss', currency_change: loser_currency)
    end

    def cancel!
      battle = open_battle_for(@actor)
      return payload(BattleConfig.message(:no_battle)) unless battle

      with_battle_locks(battle) do
        battle.lock!
        battle.update!(state: 'cancelled', winner_account: nil, loser_account: nil, finished_at: Time.current) if GameBattle::OPEN_STATES.include?(battle.state)
      end
      payload(BattleConfig.message(:battle_cancelled), accounts: participants(battle))
    end

    def revenge!
      target = sole_target
      return payload(BattleConfig.message(:invalid_target)) unless target

      previous = GameBattle.where(state: 'finished').involving(@actor).order(finished_at: :desc).first
      return payload(BattleConfig.message(:revenge_unavailable)) unless previous&.loser_account_id == @actor.id && previous.winner_account_id == target.id && previous.revenge_used_at.nil?

      with_profile_locks(@actor, target) do
        previous.lock!
        return payload(BattleConfig.message(:already_in_battle)) if open_battle_for(@actor) || open_battle_for(target)
        return payload(BattleConfig.message(:revenge_unavailable)) if previous.revenge_used_at?

        hp = BattleConfig.fetch(:max_hp)
        battle = GameBattle.create!(challenger_account: @actor, opponent_account: target, state: 'active', current_turn: 1, challenger_hp: hp, opponent_hp: hp, revenge_of: previous)
        battle.turns.create!(turn_number: 1, challenger_action: 'attack', challenger_status_id: @status.id.to_s)
        previous.update!(revenge_used_at: Time.current)
      end
      payload(BattleConfig.message(:revenge_started, challenger: label(@actor)), accounts: [@actor, target])
    end

    def kill!
      battle = GameBattle.where(state: 'finished').involving(@actor).order(finished_at: :desc).first
      return payload(BattleConfig.message(:kill_unavailable)) unless battle&.winner_account_id == @actor.id

      battle.with_lock do
        return payload(BattleConfig.message(:kill_unavailable)) if battle.kill_used_at?

        battle.update!(kill_used_at: Time.current)
      end
      payload(BattleConfig.message(:kill_script), accounts: participants(battle))
    end

    def transfer!(item_name)
      target = sole_target
      return payload(BattleConfig.message(:transfer_invalid_target)) unless target

      result = ItemTransferService.new(sender: @actor, recipient: target).transfer!(item_name)
      payload(BattleConfig.message(:transfer_completed, sender: label(@actor), recipient: label(target), item: result[:item].name, count: result[:count], limit: BattleConfig.fetch(:item_transfer_daily_limit)), accounts: [@actor, target])
    rescue Error => e
      payload(e.message)
    end

    def sole_target
      targets = @status.mentions.includes(:account).map(&:account).reject { |account| account.id.in?([@actor.id, @bot_account.id]) }
      targets.one? ? targets.first : nil
    end

    def open_battle_for(account)
      GameBattle.open.involving(account).first
    end

    def with_profile_locks(*accounts)
      GameProfile.create_or_find_by!(account: accounts.first)
      GameProfile.create_or_find_by!(account: accounts.second)
      GameProfile.transaction do
        GameProfile.lock.where(account: accounts).order(:account_id).load
        yield
      end
    end

    def with_battle_locks(battle, &block)
      with_profile_locks(battle.challenger_account, battle.opponent_account, &block)
    end

    def side_for(battle, account)
      return 'challenger' if battle.challenger_account_id == account.id
      return 'opponent' if battle.opponent_account_id == account.id

      raise Error.new(:forbidden, BattleConfig.message(:not_your_turn))
    end

    def find_item(name, action)
      return if name.blank?

      GameItem.active.find_by(name: name, item_type: 'battle', battle_action: action, consumable: true)
    end

    def valid_battle_item?(item, action)
      item.active? && item.item_type == 'battle' && item.consumable? && item.battle_action == action
    end

    def revenge_bonus?(battle, turn, account, action)
      battle.revenge_of_id? && turn.turn_number == 1 && battle.challenger_account_id == account.id && action == 'attack'
    end

    def roll(count, sides)
      count.times.sum { SecureRandom.random_number(sides) + 1 }
    end

    def format_turn(battle, result, turn_number = battle.current_turn)
      challenger = result.fetch(:challenger, result['challenger']).with_indifferent_access
      opponent = result.fetch(:opponent, result['opponent']).with_indifferent_access
      fallbacks = result.fetch(:fallbacks, result['fallbacks'])
      details = [
        *fallbacks,
        "#{label(battle.challenger_account)} #{korean_action(challenger[:action])}: #{challenger[:total]}",
        "#{label(battle.opponent_account)} #{korean_action(opponent[:action])}: #{opponent[:total]}",
        "받은 피해: #{label(battle.challenger_account)} #{result[:challenger_damage] || result['challenger_damage']}, #{label(battle.opponent_account)} #{result[:opponent_damage] || result['opponent_damage']}",
      ].compact.join("\n")
      BattleConfig.message(:turn_result, turn: turn_number, details: details, challenger: label(battle.challenger_account), challenger_hp: battle.challenger_hp, opponent: label(battle.opponent_account), opponent_hp: battle.opponent_hp)
    end

    def participants(battle)
      [battle.challenger_account, battle.opponent_account]
    end

    def korean_action(action)
      action == 'attack' ? '공격' : '방어'
    end

    def label(account)
      "@#{account.acct}"
    end

    def payload(text, accounts: [@actor])
      { text: text, account_accts: accounts.map(&:acct).uniq, in_reply_to_id: @status.id.to_s, visibility: @status.visibility }
    end
  end
end
