# frozen_string_literal: true

module Game
  class ItemTransferService
    def initialize(sender:, recipient:)
      @sender = sender
      @recipient = recipient
    end

    def transfer!(item_name)
      name = item_name.to_s.strip
      raise Error.new(:invalid_item, '양도할 아이템 이름을 [양도/아이템이름] 형식으로 입력해 주세요.') if name.blank?

      item = GameItem.find_by(name: name)
      raise Error.new(:not_owned, '양도할 아이템을 보유하고 있지 않습니다.') unless item

      GameProfile.transaction do
        lock_profiles!
        sender_inventory, recipient_inventory = lock_inventories!(item)
        raise Error.new(:not_owned, '양도할 아이템을 보유하고 있지 않습니다.') unless sender_inventory&.quantity&.positive?

        usage = lock_daily_usage!
        limit = BattleConfig.fetch(:item_transfer_daily_limit)
        raise Error.new(:daily_limit, BattleConfig.message(:transfer_daily_limit, limit: limit)) if usage.count >= limit

        sender_inventory.update!(quantity: sender_inventory.quantity - 1)
        recipient_inventory.update!(quantity: recipient_inventory.quantity + 1)
        usage.increment!(:count)

        GameTransaction.create!(account: @sender, action_type: 'transfer_out', game_item: item, item_change: -1)
        GameTransaction.create!(account: @recipient, action_type: 'transfer_in', game_item: item, item_change: 1)

        { item: item, count: usage.count }
      end
    end

    private

    def lock_profiles!
      [@sender, @recipient].each { |account| GameProfile.create_or_find_by!(account: account) }
      GameProfile.lock.where(account: [@sender, @recipient]).order(:account_id).load
    end

    def lock_inventories!(item)
      inventories = GameInventory.lock.where(account: [@sender, @recipient], game_item: item).order(:account_id).index_by(&:account_id)
      sender_inventory = inventories[@sender.id]
      recipient_inventory = inventories[@recipient.id] || GameInventory.create_or_find_by!(account: @recipient, game_item: item)
      recipient_inventory.lock!

      [sender_inventory, recipient_inventory]
    end

    def lock_daily_usage!
      usage = GameDailyUsage.find_or_create_by!(account: @sender, action_type: 'item_transfer', usage_date: Time.zone.today)
      usage.lock!
      usage
    end
  end
end
