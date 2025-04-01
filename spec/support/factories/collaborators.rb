# frozen_string_literal: true

FactoryBot.define do
  factory :collaborator do
    association :affiliate_user, factory: :affiliate_user
    association :seller, factory: :user
    apply_to_all_products { true }
    affiliate_basis_points { 30_00 }
  end
end
