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
      board.submissions.create!(game_bingo_item_id: selected_item_id, url: url.to_s.strip)
      count = board.bingo_count
      board.update!(completed_at: Time.current) if count.positive? && board.completed_at.nil?
      board_payload(event, board.reload)
    end
  rescue ActiveRecord::RecordNotFound
    raise Game::Error.new(:bingo_not_found, '빙고 이벤트 또는 빙고판을 찾을 수 없습니다.')
  rescue ActiveRecord::RecordNotUnique
    raise Game::Error.new(:already_checked, '이미 링크를 제출한 빙고 칸입니다.')
  rescue ActiveRecord::RecordInvalid => e
    raise Game::Error.new(:invalid_submission, e.record.errors.full_messages.to_sentence)
  end

  private

  def find_or_create_board(event, items)
    event.boards.create_or_find_by!(account: @account) do |board|
      board.item_ids = items.sample(9).map(&:id)
    end
  end

  def board_payload(event, board)
    items = event.items.index_by(&:id)
    submissions = board.submissions.index_by(&:game_bingo_item_id)
    {
      id: event.id,
      title: event.title,
      description: event.description,
      ends_at: event.ends_at,
      bingo_count: board.bingo_count,
      completed: board.completed_at.present?,
      cells: board.item_ids.map do |item_id|
        item = items[item_id]
        submission = submissions[item_id]
        { id: item.id, title: item.title, description: item.description, checked: submission.present?, url: submission&.url }
      end,
    }
  end
end
