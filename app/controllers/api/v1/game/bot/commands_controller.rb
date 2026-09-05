# frozen_string_literal: true

class Api::V1::Game::Bot::CommandsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:statuses' }
  before_action :require_user!
  before_action :require_game_bot!

  def create
    status = Status.includes(mentions: :account).find(params.require(:status_id))
    return render json: { error: '봇이 태그된 게시물만 처리할 수 있습니다.' }, status: :unprocessable_content unless status.mentions.any? { |mention| mention.account_id == current_account.id }

    render json: Game::BattleService.new(status: status, bot_account: current_account).call
  rescue ActiveRecord::RecordNotFound
    render json: { error: '게시물을 찾을 수 없습니다.' }, status: 404
  rescue Game::Error => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_content
  end

  private

  def require_game_bot!
    expected = ENV.fetch('GAME_BOT_ACCOUNT_USERNAME', 'battle_bot')
    render json: { error: '전투 봇 계정만 접근할 수 있습니다.' }, status: 403 unless current_account.local? && current_account.username == expected
  end
end
