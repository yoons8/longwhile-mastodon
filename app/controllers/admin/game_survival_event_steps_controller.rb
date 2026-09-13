# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts
class Admin::GameSurvivalEventStepsController < Admin::BaseController
  before_action :set_event
  before_action :set_step, only: [:edit, :update, :destroy]

  def index
    authorize :game_admin, :index?
    @steps = @event.steps
  end

  def new
    authorize :game_admin, :create?
    @step = @event.steps.new(position: (@event.steps.maximum(:position) || 0) + 1, choices: ['', '', ''])
  end

  def edit
    authorize :game_admin, :update?
  end

  def create
    authorize :game_admin, :create?
    @step = @event.steps.new(resource_params)
    return redirect_to(admin_game_survival_event_steps_path(@event), notice: '이벤트 단계를 추가했습니다.') if @step.save

    render :new, status: 422
  end

  def update
    authorize :game_admin, :update?
    return redirect_to(admin_game_survival_event_steps_path(@event), notice: '이벤트 단계를 수정했습니다.') if @step.update(resource_params)

    render :edit, status: 422
  end

  def destroy
    authorize :game_admin, :destroy?
    notice = @step.destroy ? '이벤트 단계를 삭제했습니다.' : @step.errors.full_messages.to_sentence
    redirect_to admin_game_survival_event_steps_path(@event), notice: notice
  end

  private

  def set_event
    @event = GameSurvivalEvent.find(params[:game_survival_event_id])
  end

  def set_step
    @step = @event.steps.find(params[:id])
  end

  def resource_params
    permitted = params.expect(game_survival_event_step: [:position, :title, :description, :survival_choice, choices: []])
    permitted[:choices] = Array(permitted[:choices]).map(&:strip)
    permitted
  end
end
# rubocop:enable Rails/I18nLocaleTexts
