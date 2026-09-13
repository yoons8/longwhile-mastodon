# frozen_string_literal: true

class Game::BingoService
  def initialize(account)
    @account = account
  end

  def boards
    GameBingoEvent.active.available_at(Time.current).includes(:items).filter_map do |event|
      active_items = event.items.select(&:active?)
      next if active_items.size < 9

      board = find_or_create_board(event, active_items)
      board_payload(event, board)
    end
  end

  def submit!(event_id, item_id, url)
    event = GameBingoEvent.find(event_id)
    raise Game::Error.new(:event_unavailable, '현재 참여할 수 없는 빙고 이벤트입니다.') unless event.available?

    board = event.boards.find_by!(account: @account)
    selected_item_id = Integer(item_id, exception: false)
    raise Game::Error.new(:invalid_cell, '빙고판에 없는 항목입니다.') unless selected_item_id && board.item_ids.include?(selected_item_id)

    GameBingoBoard.transaction do
      board.lock!
      raise Game::Error.new(:already_checked, '이미 링크를 제출한 빙고 칸입니다.') if board.submissions.exists?(game_bingo_item_id: selected_item_id)

      item = event.items.find(selected_item_id)
      submission = board.submissions.create!(game_bingo_item: item, url: url.to_s.strip)
      cell_reward = award_cell!(submission, item)
      count = board.bingo_count
      awarded_rewards = award_reached_levels!(event, board, count)
      board.update!(completed_at: Time.current) if count.positive? && board.completed_at.nil?
      board_payload(event, board.reload, awarded_rewards: [cell_reward, *awarded_rewards].compact)
    end
  rescue ActiveRecord::RecordNotFound
    raise Game::Error.new(:bingo_not_found, '빙고 이벤트 또는 빙고판을 찾을 수 없습니다.')
  rescue ActiveRecord::RecordNotUnique
    raise Game::Error.new(:already_checked, '이미 링크를 제출한 빙고 칸입니다.')
  rescue ActiveRecord::RecordInvalid => e
    raise Game::Error.new(:invalid_submission, e.record.errors.full_messages.to_sentence)
  end

  private

  def award_cell!(submission, item)
    reward_item = item.reward_game_item
    reward_quantity = reward_item ? item.reward_item_quantity : 0
    apply_reward!(reward_item, reward_quantity, item.reward_currency, item.reward_reputation)
    submission.update!(reward_game_item: reward_item, reward_item_quantity: reward_quantity, reward_currency: item.reward_currency, reward_reputation: item.reward_reputation, rewarded_at: Time.current)
    { bingo_count: 0, summary: "칸 보상: #{submission.reward_summary}" }
  end

  def award_reached_levels!(event, board, count)
    event.rewards.where(bingo_count: ..count).order(:bingo_count).filter_map do |reward|
      next if board.reward_grants.exists?(game_bingo_reward: reward)

      award!(board, reward)
    end
  end

  def award!(board, reward)
    reward_item = reward.game_item
    reward_quantity = reward_item ? reward.item_quantity : 0
    apply_reward!(reward_item, reward_quantity, reward.currency, reward.reputation)

    grant = board.reward_grants.create!(game_bingo_reward: reward, game_item: reward_item, bingo_count: reward.bingo_count, item_quantity: reward_quantity, currency: reward.currency, reputation: reward.reputation)
    { bingo_count: grant.bingo_count, summary: grant.summary }
  end

  def apply_reward!(reward_item, reward_quantity, currency, reputation)
    profile = GameProfile.create_or_find_by!(account: @account)
    profile.lock!
    profile.update!(currency: profile.currency + currency, reputation: profile.reputation + reputation)

    if reward_item && reward_quantity.positive?
      inventory = GameInventory.create_or_find_by!(account: @account, game_item: reward_item)
      inventory.lock!
      inventory.update!(quantity: inventory.quantity + reward_quantity)
    end

    GameTransaction.create!(account: @account, action_type: 'bingo_reward', game_item: reward_item, currency_change: currency, item_change: reward_quantity)
  end

  def find_or_create_board(event, items)
    event.boards.create_or_find_by!(account: @account) do |board|
      board.item_ids = items.sample(9).map(&:id)
    end
  end

  def board_payload(event, board, awarded_rewards: [])
    items = event.items.index_by(&:id)
    submissions = board.submissions.index_by(&:game_bingo_item_id)
    granted_levels = board.reward_grants.pluck(:bingo_count).to_set
    {
      id: event.id,
      title: event.title,
      description: event.description,
      ends_at: event.ends_at,
      bingo_count: board.bingo_count,
      completed: board.completed_at.present?,
      awarded_rewards: awarded_rewards,
      reward_levels: event.rewards.includes(:game_item).order(:bingo_count).map { |reward| { bingo_count: reward.bingo_count, summary: reward.summary, achieved: granted_levels.include?(reward.bingo_count) } },
      cells: board.item_ids.map do |item_id|
        item = items[item_id]
        submission = submissions[item_id]
        { id: item.id, title: item.title, description: item.description, checked: submission.present?, url: submission&.url }
      end,
    }
  end
end
