# frozen_string_literal: true

class Admin::GameBingoEventsController < Admin::BaseController
  before_action :set_event, only: [:edit, :update, :destroy]

  def index
    authorize :game_admin, :index?
    @events = GameBingoEvent.includes(:items, :rewards, boards: [:submissions, :reward_grants]).order(created_at: :desc).page(params[:page])
  end

  def new
    authorize :game_admin, :create?
    @event = GameBingoEvent.new
  end

  def edit
    authorize :game_admin, :update?
  end

  def create
    authorize :game_admin, :create?
    @event = GameBingoEvent.new(resource_params)
    return redirect_to(admin_game_bingo_event_items_path(@event), notice: '빙고 이벤트를 등록했습니다. 항목을 9개 이상 추가해 주세요.') if @event.save

    render :new, status: 422
  end

  def update
    authorize :game_admin, :update?
    return redirect_to(admin_game_bingo_events_path, notice: '빙고 이벤트를 수정했습니다.') if @event.update(resource_params)

    render :edit, status: 422
  end

  def destroy
    authorize :game_admin, :destroy?
    @event.update_column(:active, false)
    redirect_to admin_game_bingo_events_path, notice: '빙고 이벤트를 비활성화했습니다.'
  end

  private

  def set_event = @event = GameBingoEvent.find(params[:id])
  def resource_params = params.expect(game_bingo_event: [:title, :description, :active, :starts_at, :ends_at])
end
