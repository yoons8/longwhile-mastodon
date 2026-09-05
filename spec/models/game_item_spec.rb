# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GameItem do
  it 'allows a non-battle item with an empty battle action from the admin form' do
    item = described_class.new(name: '장식용 리본', base_price: 10, item_type: 'miscellaneous', battle_action: '')

    expect(item).to be_valid
    expect(item.battle_action).to be_nil
  end
end
