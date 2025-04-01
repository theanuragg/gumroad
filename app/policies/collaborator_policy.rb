# frozen_string_literal: true

class CollaboratorPolicy < ApplicationPolicy
  def index?
    user.role_admin_for?(seller)
  end

  def create?
    index?
  end

  def new?
    index?
  end

  def edit?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index? && record.seller == seller
  end
end
