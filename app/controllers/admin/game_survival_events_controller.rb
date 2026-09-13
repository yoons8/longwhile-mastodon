# frozen_string_literal: true

class Admin::GameSurvivalEventsController < Admin::BaseController
  before_action :set_event, only: [:edit, :update, :destroy, :reset_entries]

  def index
    authorize :game_admin, :index?
    @events = GameSurvivalEvent.includes(:entries, :steps).order(created_at: :desc).page(params[:page])
  end

  def new
    authorize :game_admin, :create?
    @event = GameSurvivalEvent.new
    prepare_form
  end

  def edit
    authorize :game_admin, :update?
    prepare_form
  end

  def create
    authorize :game_admin, :create?
    @event = GameSurvivalEvent.new(resource_params)
    return redirect_to(admin_game_survival_event_steps_path(@event), notice: '이벤트를 등록했습니다. 첫 단계를 추가해 주세요.') if @event.save

    prepare_form
    render :new, status: 422
  end

  def update
    authorize :game_admin, :update?
    saved = false
    GameSurvivalEvent.transaction do
      saved = @event.update(resource_params)
      raise ActiveRecord::Rollback unless saved
    end
    return redirect_to(admin_game_survival_events_path, notice: '생존 이벤트를 수정했습니다.') if saved

    prepare_form
    render :edit, status: 422
  end

  def reset_entries
    authorize :game_admin, :update?
    count = @event.entries.delete_all
    redirect_to admin_game_survival_events_path, notice: "참여 기록 #{count}건을 초기화했습니다. 지급된 아이템은 회수하지 않았습니다."
  end

  def destroy
    authorize :game_admin, :destroy?
    @event.update_column(:active, false)
    redirect_to admin_game_survival_events_path, notice: '생존 이벤트를 비활성화했습니다.'
  end

  private

  def set_event
    @event = GameSurvivalEvent.find(params[:id])
  end

  def resource_params
    permitted = params.expect(game_survival_event: [:title, :description, :active, :starts_at, :ends_at, :background_image, :remove_background_image, failure_messages: [], reward_item_ids: []])
    permitted[:failure_messages] = Array(permitted[:failure_messages]).map(&:strip).compact_blank
    permitted
  end

  def prepare_form
    @game_items = GameItem.where(id: @event.reward_item_ids).or(GameItem.active).order(:name)
  end
end
