# frozen_string_literal: true

class Admin::GameBingoRewardsController < Admin::BaseController
  before_action :set_event
  before_action :set_reward, only: [:edit, :update, :destroy]

  def index
    authorize :game_admin, :index?
    @rewards = @event.rewards.includes(:game_item).order(:bingo_count)
  end

  def new
    authorize :game_admin, :create?
    @reward = @event.rewards.new
  end

  def edit
    authorize :game_admin, :update?
  end

  def create
    authorize :game_admin, :create?
    @reward = @event.rewards.new(resource_params)
    return redirect_to(admin_game_bingo_event_rewards_path(@event), notice: '빙고 단계 보상을 추가했습니다.') if @reward.save

    render :new, status: 422
  end

  def update
    authorize :game_admin, :update?
    return redirect_to(admin_game_bingo_event_rewards_path(@event), notice: '빙고 단계 보상을 수정했습니다.') if @reward.update(resource_params)

    render :edit, status: 422
  end

  def destroy
    authorize :game_admin, :destroy?
    return redirect_to(admin_game_bingo_event_rewards_path(@event), alert: '이미 지급된 보상 단계는 삭제할 수 없습니다.') if @reward.grants.exists?

    @reward.destroy!
    redirect_to admin_game_bingo_event_rewards_path(@event), notice: '빙고 단계 보상을 삭제했습니다.'
  end

  private

  def set_event = @event = GameBingoEvent.find(params[:game_bingo_event_id])
  def set_reward = @reward = @event.rewards.find(params[:id])
  def resource_params = params.expect(game_bingo_reward: [:bingo_count, :game_item_id, :item_quantity, :currency, :reputation])
end
