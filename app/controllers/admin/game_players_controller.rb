# frozen_string_literal: true

class Admin::GamePlayersController < Admin::BaseController
  EMPTY_RECORD = { wins: 0, losses: 0, draws: 0 }.freeze

  def index
    authorize :game_admin, :index?

    @game_profiles = filtered_profiles.includes(:account).order(reputation: :desc, currency: :desc, id: :asc).page(params[:page])
    account_ids = @game_profiles.map(&:account_id)
    @battle_records = battle_records_for(account_ids)
    @inventory_summaries = inventory_summaries_for(account_ids)
  end

  def show
    authorize :game_admin, :show?

    @game_profile = GameProfile.includes(:account).find(params[:id])
    @account = @game_profile.account
    @battle_record = battle_records_for([@account.id]).fetch(@account.id, EMPTY_RECORD)
    @inventories = GameInventory.owned.where(account: @account).joins(:game_item).includes(:game_item).order('game_items.name ASC').page(params[:inventory_page])
    @game_battles = finished_battles_for(@account).includes(:challenger_account, :opponent_account, :winner_account).order(finished_at: :desc).limit(30)
    @game_transactions = GameTransaction.where(account: @account).includes(:game_item).order(created_at: :desc).limit(30)
  end

  def update
    authorize :game_admin, :update?

    @game_profile = GameProfile.find(params[:id])
    @game_profile.with_lock { @game_profile.update!(reputation_params) }
    redirect_to admin_game_player_path(@game_profile), notice: I18n.t('admin.game_players.reputation_updated')
  rescue ActiveRecord::RecordInvalid
    redirect_to admin_game_player_path(@game_profile), alert: I18n.t('admin.game_players.invalid_reputation')
  end

  private

  def filtered_profiles
    profiles = GameProfile.joins(:account).where(accounts: { domain: nil })
    query = params[:q].to_s.strip
    return profiles if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    profiles.where('accounts.username ILIKE :term OR accounts.display_name ILIKE :term', term: term)
  end

  def inventory_summaries_for(account_ids)
    GameInventory.owned.where(account_id: account_ids).group(:account_id).pluck(:account_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(quantity), 0)')).to_h do |account_id, kinds, quantity|
      [account_id, { kinds: kinds, quantity: quantity }]
    end
  end

  def battle_records_for(account_ids)
    records = Hash.new { |hash, key| hash[key] = EMPTY_RECORD.dup }
    GameBattle.where(state: 'finished', winner_account_id: account_ids).group(:winner_account_id).count.each { |account_id, count| records[account_id][:wins] = count }
    GameBattle.where(state: 'finished', loser_account_id: account_ids).group(:loser_account_id).count.each { |account_id, count| records[account_id][:losses] = count }

    draw_counts = GameBattle.where(state: 'finished', winner_account_id: nil, challenger_account_id: account_ids).group(:challenger_account_id).count
    GameBattle.where(state: 'finished', winner_account_id: nil, opponent_account_id: account_ids).group(:opponent_account_id).count.each do |account_id, count|
      draw_counts[account_id] = draw_counts.fetch(account_id, 0) + count
    end
    draw_counts.each { |account_id, count| records[account_id][:draws] = count }
    records
  end

  def finished_battles_for(account)
    GameBattle.where(state: 'finished', challenger_account: account).or(GameBattle.where(state: 'finished', opponent_account: account))
  end

  def reputation_params
    params.expect(game_profile: [:reputation])
  end
end
