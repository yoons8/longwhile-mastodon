# frozen_string_literal: true

class Admin::GameBingoItemsController < Admin::BaseController
  before_action :set_event
  before_action :set_item, only: [:edit, :update, :destroy]

  def index
    authorize :game_admin, :index?
    @items = @event.items.order(:created_at)
  end

  def new
    authorize :game_admin, :create?
    @item = @event.items.new
  end

  def edit
    authorize :game_admin, :update?
  end

  def create
    authorize :game_admin, :create?
    @item = @event.items.new(resource_params)
    return redirect_to(admin_game_bingo_event_items_path(@event), notice: '빙고 항목을 추가했습니다.') if @item.save

    render :new, status: 422
  end

  def update
    authorize :game_admin, :update?
    return redirect_to(admin_game_bingo_event_items_path(@event), notice: '빙고 항목을 수정했습니다.') if @item.update(resource_params)

    render :edit, status: 422
  end

  def destroy
    authorize :game_admin, :destroy?
    @item.update_column(:active, false)
    redirect_to admin_game_bingo_event_items_path(@event), notice: '빙고 항목을 비활성화했습니다.'
  end

  private

  def set_event = @event = GameBingoEvent.find(params[:game_bingo_event_id])
  def set_item = @item = @event.items.find(params[:id])
  def resource_params = params.expect(game_bingo_item: [:title, :description, :active, :reward_game_item_id, :reward_item_quantity, :reward_currency, :reward_reputation])
end
