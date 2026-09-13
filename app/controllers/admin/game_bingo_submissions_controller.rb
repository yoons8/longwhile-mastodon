# frozen_string_literal: true

class Admin::GameBingoSubmissionsController < Admin::BaseController
  def index
    authorize :game_admin, :index?
    @event = GameBingoEvent.find(params[:game_bingo_event_id])
    @items = @event.items.includes(:reward_game_item, submissions: [:reward_game_item, { game_bingo_board: :account }]).order(:created_at)
    @reward_grants = GameBingoRewardGrant.joins(:game_bingo_board).where(game_bingo_boards: { game_bingo_event_id: @event.id }).includes(:game_item, game_bingo_board: :account).order(bingo_count: :asc, created_at: :desc)
    @boards = @event.boards.includes(:submissions)
  end
end
