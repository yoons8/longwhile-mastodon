# frozen_string_literal: true

class Admin::GameBingoSubmissionsController < Admin::BaseController
  def index
    authorize :game_admin, :index?
    @event = GameBingoEvent.find(params[:game_bingo_event_id])
    @submissions = GameBingoSubmission.joins(:game_bingo_board).where(game_bingo_boards: { game_bingo_event_id: @event.id }).includes(:game_bingo_item, game_bingo_board: :account).order(created_at: :desc).page(params[:page])
  end
end
