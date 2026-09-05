# frozen_string_literal: true

class CreateGameSystem < ActiveRecord::Migration[8.0]
  def change
    create_table :game_profiles do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.bigint :currency, null: false, default: 0
      t.integer :reputation, null: false, default: 0
      t.timestamps
    end

    create_table :game_items do |t|
      t.string :name, null: false
      t.text :description, null: false, default: ''
      t.bigint :base_price, null: false
      t.string :item_type, null: false
      t.boolean :consumable, null: false, default: false
      t.boolean :active, null: false, default: true
      t.string :image_file_name
      t.string :image_content_type
      t.integer :image_file_size
      t.datetime :image_updated_at
      t.timestamps
    end
    add_index :game_items, [:active, :item_type]

    create_table :game_inventories do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_item, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false, default: 0
      t.timestamps
    end
    add_index :game_inventories, [:account_id, :game_item_id], unique: true

    create_table :game_daily_usages do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :action_type, null: false
      t.date :usage_date, null: false
      t.integer :count, null: false, default: 0
      t.timestamps
    end
    add_index :game_daily_usages, [:account_id, :action_type, :usage_date], unique: true, name: 'index_game_daily_usages_unique_action'

    create_table :game_shops do |t|
      t.string :name, null: false
      t.text :description, null: false, default: ''
      t.string :shop_type, null: false, default: 'normal'
      t.boolean :active, null: false, default: true
      t.integer :min_reputation, null: false, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end
    add_index :game_shops, [:active, :shop_type]
    add_index :game_shops, [:starts_at, :ends_at]

    create_table :game_shop_items do |t|
      t.references :game_shop, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_item, null: false, foreign_key: { on_delete: :restrict }
      t.bigint :price, null: false
      t.integer :stock
      t.integer :purchase_limit
      t.integer :min_reputation, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :game_shop_items, [:game_shop_id, :game_item_id], unique: true
    add_index :game_shop_items, [:game_shop_id, :active]

    create_table :game_transactions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :action_type, null: false
      t.references :game_item, null: true, foreign_key: { on_delete: :restrict }
      t.bigint :currency_change, null: false, default: 0
      t.integer :item_change, null: false, default: 0
      t.datetime :created_at, null: false
    end
    add_index :game_transactions, [:account_id, :created_at]
    add_index :game_transactions, [:account_id, :action_type, :created_at], name: 'index_game_transactions_on_account_action_created'

    add_check_constraint :game_profiles, 'currency >= 0', name: 'game_profiles_currency_nonnegative'
    add_check_constraint :game_profiles, 'reputation >= 0', name: 'game_profiles_reputation_nonnegative'
    add_check_constraint :game_items, 'base_price >= 0', name: 'game_items_base_price_nonnegative'
    add_check_constraint :game_inventories, 'quantity >= 0', name: 'game_inventories_quantity_nonnegative'
    add_check_constraint :game_daily_usages, 'count >= 0', name: 'game_daily_usages_count_nonnegative'
    add_check_constraint :game_shops, 'min_reputation >= 0', name: 'game_shops_min_reputation_nonnegative'
    add_check_constraint :game_shop_items, 'price >= 0', name: 'game_shop_items_price_nonnegative'
    add_check_constraint :game_shop_items, 'min_reputation >= 0', name: 'game_shop_items_min_reputation_nonnegative'
    add_check_constraint :game_shop_items, 'stock IS NULL OR stock >= 0', name: 'game_shop_items_stock_nonnegative'
    add_check_constraint :game_shop_items, 'purchase_limit IS NULL OR purchase_limit > 0', name: 'game_shop_items_purchase_limit_positive'
  end
end
