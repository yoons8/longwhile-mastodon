# frozen_string_literal: true

class Admin::GameItemsController < Admin::BaseController
  before_action :set_item, only: [:edit, :update, :destroy]

  def index
    authorize :game_admin, :index?
    @game_items = GameItem.order(:name).page(params[:page])
  end

  def new
    authorize :game_admin, :create?
    @game_item = GameItem.new
  end

  def create
    authorize :game_admin, :create?
    @game_item = GameItem.new(resource_params)
    return redirect_to(admin_game_items_path, notice: '아이템을 등록했습니다.') if @game_item.save

    render :new, status: :unprocessable_entity
  end

  def edit
    authorize :game_admin, :update?
  end

  def update
    authorize :game_admin, :update?
    return redirect_to(admin_game_items_path, notice: '아이템을 수정했습니다.') if @game_item.update(resource_params)

    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize :game_admin, :destroy?
    @game_item.update!(active: false)
    redirect_to admin_game_items_path, notice: '아이템을 비활성화했습니다.'
  end

  private

  def set_item
    @game_item = GameItem.find(params[:id])
  end

  def resource_params
    params.expect(game_item: [:name, :description, :base_price, :min_reputation, :item_type, :consumable, :active, :image, :battle_action, :dice_count, :dice_sides, :flat_bonus])
  end
end
