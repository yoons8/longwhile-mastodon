# frozen_string_literal: true

class Game::SurvivalEventService
  def initialize(account)
    @account = account
  end

  def choose!(event_id, choice)
    event = GameSurvivalEvent.find(event_id)
    selected_choice = Integer(choice, exception: false)
    raise Game::Error.new(:invalid_choice, '선택지를 골라 주세요.') unless selected_choice&.between?(0, 2)

    entry = GameSurvivalEventEntry.transaction do
      event.lock!
      raise Game::Error.new(:event_unavailable, '현재 참여할 수 없는 이벤트입니다.') unless event.available?
      raise Game::Error.new(:event_not_ready, '이벤트 설정이 완료되지 않았습니다.') unless event.ready?

      steps = event.steps.to_a
      raise Game::Error.new(:event_has_no_steps, '아직 단계가 등록되지 않은 이벤트입니다.') if steps.empty?

      current_entry = event.entries.find_or_initialize_by(account: @account)
      current_entry.lock! if current_entry.persisted?
      raise Game::Error.new(:event_finished, '이미 종료된 이벤트입니다.') if current_entry.finished?

      step_index = current_entry.current_step_index
      step = steps.fetch(step_index)
      survived = selected_choice == step.survival_choice
      next_step_index = step_index + 1
      status = if !survived
                 'eliminated'
               elsif next_step_index >= steps.length
                 'completed'
               else
                 'in_progress'
               end
      outcome_message = survived ? nil : event.normalized_failure_messages.sample
      reward_item = status == 'completed' ? event.reward_items.to_a.sample : nil

      current_entry.assign_attributes(
        choice: selected_choice,
        survived: survived,
        current_step_index: next_step_index,
        status: status,
        results: Array(current_entry.results) + [{ step_id: step.id, choice: selected_choice, survived: survived }],
        outcome_message: outcome_message,
        reward_game_item: reward_item
      )
      current_entry.save!
      grant_reward!(reward_item) if reward_item

      current_entry
    end

    payload(event, entry)
  rescue ActiveRecord::RecordNotFound
    raise Game::Error.new(:event_not_found, '이벤트를 찾을 수 없습니다.')
  rescue ActiveRecord::RecordNotUnique
    raise Game::Error.new(:choice_already_submitted, '선택이 이미 처리되었습니다. 화면을 새로고침해 주세요.')
  end

  private

  def payload(event, entry)
    last_result = entry.results.last
    step = event.steps.find(last_result.fetch('step_id', last_result[:step_id]))

    {
      event_id: event.id,
      choice: entry.choice,
      survived: entry.survived,
      survival_choice: step.survival_choice,
      status: entry.status,
      current_step: entry.current_step_index,
      total_steps: event.steps.size,
      message: result_message(entry),
      reward_item: reward_payload(entry.reward_game_item),
    }
  end

  def result_message(entry)
    return entry.outcome_message if entry.eliminated?
    return "모든 단계를 통과했습니다! #{entry.reward_game_item.name}을(를) 획득했습니다." if entry.completed?

    '생존했습니다. 다음 단계로 이동합니다.'
  end

  def grant_reward!(item)
    inventory = GameInventory.create_or_find_by!(account: @account, game_item: item)
    inventory.lock!
    inventory.increment!(:quantity)
    GameTransaction.create!(account: @account, game_item: item, action_type: 'survival_reward', item_change: 1)
  end

  def reward_payload(item)
    return if item.nil?

    { id: item.id, name: item.name, image: item.image.exists? ? item.image.url(:small) : nil }
  end
end
