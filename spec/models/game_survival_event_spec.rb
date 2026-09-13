# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GameSurvivalEvent do
  subject(:event) { described_class.new(title: '동굴 탈출', failure_messages: Array.new(7) { |index| "탈락 #{index}" }, reward_item_ids: reward_items.map(&:id)) }

  let(:reward_items) { Array.new(7) { |index| GameItem.create!(name: "보상 #{index}", base_price: 0, item_type: 'miscellaneous') } }

  it 'requires the end to be after the start' do
    event.starts_at = Time.zone.now
    event.ends_at = event.starts_at

    expect(event).to_not be_valid
  end

end

RSpec.describe GameSurvivalEventStep do
  subject(:step) { described_class.new(game_survival_event: event, position: 1, title: '갈림길', choices: %w(왼쪽 가운데 오른쪽), survival_choice: 1) }

  let(:reward_items) { Array.new(7) { |index| GameItem.create!(name: "보상 #{index}", base_price: 0, item_type: 'miscellaneous') } }
  let(:event) { GameSurvivalEvent.create!(title: '동굴 탈출', failure_messages: Array.new(7) { |index| "탈락 #{index}" }, reward_item_ids: reward_items.map(&:id)) }

  it 'requires exactly three non-empty choices' do
    step.choices = ['하나', '둘']

    expect(step).to_not be_valid
    expect(step.errors[:choices]).to be_present
  end

  it 'keeps step rules fixed after someone participates' do
    step.save!
    event.entries.create!(account: Fabricate(:account), choice: 1, survived: true)

    expect(step.update(survival_choice: 2)).to be(false)
  end
end
