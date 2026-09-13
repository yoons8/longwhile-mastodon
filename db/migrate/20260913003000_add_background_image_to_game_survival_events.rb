# frozen_string_literal: true

class AddBackgroundImageToGameSurvivalEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :game_survival_events, :background_image_file_name, :string
    add_column :game_survival_events, :background_image_content_type, :string
    add_column :game_survival_events, :background_image_file_size, :integer
    add_column :game_survival_events, :background_image_updated_at, :datetime
  end
end
