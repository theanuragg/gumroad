# frozen_string_literal: true

class CollaboratorsPresenter
  def initialize(seller:)
    @seller = seller
  end

  def index_props
    {
      collaborators: seller.collaborators.alive.map do
        CollaboratorPresenter.new(seller:, collaborator: _1).collaborator_props
      end,
      collaborators_disabled_reason: seller.has_brazilian_stripe_connect_account? ? "Collaborators with Brazilian Stripe accounts are not supported." : nil
    }
  end

  private
    attr_reader :seller
end
