# frozen_string_literal: true

class Game::BingoRewardFormatter
  def self.call(item, item_quantity, currency, reputation)
    parts = []
    parts << "#{item.name} #{item_quantity}개" if item && item_quantity.positive?
    parts << "재화 #{currency}" if currency.positive?
    parts << "명성 #{reputation}" if reputation.positive?
    parts.presence&.join(', ') || '보상 없음'
  end
end
