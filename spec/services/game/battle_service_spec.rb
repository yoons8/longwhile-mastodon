# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Game::BattleService do
  let(:challenger) { Fabricate(:account, username: 'fighter_one') }
  let(:opponent) { Fabricate(:account, username: 'fighter_two') }
  let(:bot) { Fabricate(:account, username: 'battle_bot') }

  def command_status(account, text, targets: [])
    status = Fabricate(:status, account: account, text: text)
    (targets + [bot]).uniq.each { |target| Mention.create!(status: status, account: target) }
    status
  end

  def process(account, text, targets: [])
    described_class.new(status: command_status(account, text, targets: targets), bot_account: bot).call
  end

  def start_battle
    process(challenger, '@fighter_two @battle_bot [전투]', targets: [opponent])
    process(opponent, '@fighter_one @battle_bot [승낙]', targets: [challenger])
    GameBattle.last
  end

  describe 'challenge lifecycle' do
    it 'creates, accepts, and cancels a battle without rewards' do
      challenger.update!(display_name: '신청자')
      opponent.update!(display_name: '상대방')
      response = process(challenger, '@fighter_two @battle_bot [전투]', targets: [opponent])
      battle = GameBattle.last

      expect(response[:text]).to include('신청자 님이 상대방 님에게 전투를 신청')
      expect(battle.state).to eq('pending')

      process(opponent, '@fighter_one @battle_bot [승낙]', targets: [challenger])
      expect(battle.reload.state).to eq('active')
      expect(battle.current_turn).to eq(1)

      process(challenger, '@fighter_two @battle_bot [전투포기]', targets: [opponent])
      expect(battle.reload.state).to eq('cancelled')
      expect(battle.winner_account).to be_nil
      expect(GameTransaction.where(action_type: %w(battle_win battle_loss))).to be_empty
    end

    it 'blocks a second battle involving either participant' do
      third = Fabricate(:account, username: 'fighter_three')
      start_battle

      response = process(third, '@fighter_two @battle_bot [전투]', targets: [opponent])

      expect(response[:text]).to include('상대방이 이미 전투 중')
      expect(GameBattle.count).to eq(1)
    end

    it 'decreases rejecting opponent reputation when rejected' do
      GameProfile.create!(account: challenger, reputation: 3)
      GameProfile.create!(account: opponent, reputation: 3)
      process(challenger, '@fighter_two @battle_bot [전투]', targets: [opponent])

      process(opponent, '@fighter_one @battle_bot [거절]', targets: [challenger])

      expect(GameBattle.last.state).to eq('rejected')
      expect(GameProfile.find_by(account: challenger).reputation).to eq(3)
      expect(GameProfile.find_by(account: opponent).reputation).to eq(2)
    end
  end

  describe 'turn resolution' do
    it 'waits for both actions and resolves a turn exactly once' do
      battle = start_battle
      allow(SecureRandom).to receive(:random_number).and_return(5, 1)

      first = process(challenger, '@fighter_two @battle_bot [공격]', targets: [opponent])
      expect(first[:text]).to include('상대방의 입력을 기다립니다')
      expect(battle.reload.opponent_hp).to eq(20)

      second = process(opponent, '@fighter_one @battle_bot [방어]', targets: [challenger])
      expect(second[:text]).to include('받은 피해')
      expect(battle.reload.opponent_hp).to eq(16)
      expect(battle.current_turn).to eq(2)
    end

    it 'consumes an item only when both actions are resolved' do
      battle = start_battle
      item = GameItem.create!(name: '전투검', base_price: 0, item_type: 'battle', consumable: true, battle_action: 'attack', dice_count: 1, dice_sides: 6)
      inventory = GameInventory.create!(account: challenger, game_item: item, quantity: 1)

      process(challenger, '@fighter_two @battle_bot [공격/전투검]', targets: [opponent])
      expect(inventory.reload.quantity).to eq(1)

      process(opponent, '@fighter_one @battle_bot [방어]', targets: [challenger])
      expect(inventory.reload.quantity).to eq(0)
      expect(battle.turns.first).to be_resolved_at
    end

    it 'falls back to a basic action when the item is not owned' do
      start_battle
      GameItem.create!(name: '없는검', base_price: 0, item_type: 'battle', consumable: true, battle_action: 'attack', dice_count: 1, dice_sides: 6)
      process(challenger, '@fighter_two @battle_bot [공격/없는검]', targets: [opponent])

      response = process(opponent, '@fighter_one @battle_bot [방어]', targets: [challenger])

      expect(response[:text]).to include('보유하지 않아 일반 공격')
    end

    it 'finishes, rewards the winner, and enables one revenge battle' do
      battle = start_battle
      battle.update!(opponent_hp: 5)
      allow(SecureRandom).to receive(:random_number).and_return(5, 0)

      process(challenger, '@fighter_two @battle_bot [공격]', targets: [opponent])
      response = process(opponent, '@fighter_one @battle_bot [방어]', targets: [challenger])

      expect(response[:text]).to include('승리했습니다')
      expect(battle.reload).to have_attributes(state: 'finished', winner_account: challenger, loser_account: opponent)
      expect(GameProfile.find_by(account: challenger)).to have_attributes(currency: 10, reputation: 2)
      expect(GameProfile.find_by(account: opponent)).to have_attributes(currency: 2, reputation: 0)

      kill = process(challenger, '@battle_bot [살해]')
      expect(kill[:text]).to include('마지막 일격')
      expect(kill[:text]).to include('@fighter_one 님이 @fighter_two 님에게 마지막 일격')
      expect(kill[:text]).to include('@fighter_two 님은')
      expect(battle.reload.kill_used_at).to be_present

      revenge = process(opponent, '@fighter_one @battle_bot [복수]', targets: [challenger])
      expect(revenge[:text]).to include('복수 공격이 시작')
      expect(revenge[:text]).to include('@fighter_one은 [공격] 또는 [방어]를 입력')
      expect(GameBattle.last).to have_attributes(state: 'active', revenge_of: battle, challenger_account: opponent)
      expect(GameBattle.last.turns.first).to have_attributes(challenger_action: 'attack')
      expect(battle.reload.revenge_used_at).to be_present

      process(challenger, '@fighter_two @battle_bot [방어]', targets: [opponent])
      expect(GameBattle.last.turns.first.reload).to be_resolved_at
    end

    it 'declares a draw when both players reach zero together' do
      battle = start_battle
      battle.update!(challenger_hp: 1, opponent_hp: 1)
      allow(SecureRandom).to receive(:random_number).and_return(0, 0)

      process(challenger, '@fighter_two @battle_bot [공격]', targets: [opponent])
      response = process(opponent, '@fighter_one @battle_bot [공격]', targets: [challenger])

      expect(response[:text]).to include('무승부')
      expect(battle.reload).to have_attributes(state: 'finished', challenger_hp: 0, opponent_hp: 0, winner_account: nil, loser_account: nil)
    end
  end

  describe 'idempotency' do
    it 'returns the stored response for an already processed status' do
      status = command_status(challenger, '@fighter_two @battle_bot [전투]', targets: [opponent])
      service = described_class.new(status: status, bot_account: bot)

      first_response = service.call
      second_response = service.call
      expect(second_response).to eq(first_response)
      expect(GameBattle.count).to eq(1)
      expect(GameBotEvent.count).to eq(1)
    end
  end

  describe '[살해]' do
    it 'only permits the winner to use it for their most recent battle' do
      earlier_win = GameBattle.create!(challenger_account: challenger, opponent_account: opponent, winner_account: challenger, loser_account: opponent, state: 'finished', challenger_hp: 10, opponent_hp: 0, finished_at: 2.minutes.ago)
      newer_loss = GameBattle.create!(challenger_account: challenger, opponent_account: opponent, winner_account: opponent, loser_account: challenger, state: 'finished', challenger_hp: 0, opponent_hp: 10, finished_at: 1.minute.ago)

      response = process(challenger, '@fighter_two @battle_bot [살해]', targets: [opponent])

      expect(response[:text]).to include('[살해]를 사용할 수 있는 전투가 없습니다')
      expect(earlier_win.reload.kill_used_at).to be_nil
      expect(newer_loss.reload.kill_used_at).to be_nil
    end
  end

  describe 'item transfers' do
    let!(:item) { GameItem.create!(name: '선물상자', base_price: 0, item_type: 'miscellaneous') }

    it 'transfers one owned item, records both sides, and enforces the daily limit' do
      sender_inventory = GameInventory.create!(account: challenger, game_item: item, quantity: 4)

      3.times do |index|
        response = process(challenger, "@fighter_two @battle_bot [양도/선물상자] #{index}", targets: [opponent])
        expect(response[:text]).to include("오늘 양도 #{index + 1}/3회")
      end

      expect(sender_inventory.reload.quantity).to eq(1)
      expect(GameInventory.find_by!(account: opponent, game_item: item).quantity).to eq(3)
      expect(GameDailyUsage.find_by!(account: challenger, action_type: 'item_transfer', usage_date: Time.zone.today).count).to eq(3)
      expect(GameTransaction.where(account: challenger, action_type: 'transfer_out', game_item: item).count).to eq(3)
      expect(GameTransaction.where(account: opponent, action_type: 'transfer_in', game_item: item).count).to eq(3)

      response = process(challenger, '@fighter_two @battle_bot [양도/선물상자] 마지막', targets: [opponent])
      expect(response[:text]).to include('오늘 양도 횟수(3회)를 모두 사용')
      expect(sender_inventory.reload.quantity).to eq(1)
    end

    it 'does not consume a daily transfer when the sender does not own the item' do
      response = process(challenger, '@fighter_two @battle_bot [양도/없는아이템]', targets: [opponent])

      expect(response[:text]).to include('보유하고 있지 않습니다')
      expect(GameDailyUsage.where(account: challenger, action_type: 'item_transfer').count).to eq(0)
    end
  end
end
