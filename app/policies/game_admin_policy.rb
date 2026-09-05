# frozen_string_literal: true

class GameAdminPolicy < ApplicationPolicy
  def index? = role.can?(:manage_settings)
  def create? = role.can?(:manage_settings)
  def update? = role.can?(:manage_settings)
  def destroy? = role.can?(:manage_settings)
end
