# frozen_string_literal: true

class Collaborator::CreateService
  def initialize(seller:, params:)
    @seller = seller
    @params = params
  end

  def process
    collaborating_user = User.find_by(email: params[:email])
    return { success: false, message: "The email address isn't associated with a Gumroad account." } if collaborating_user.nil?

    if seller.collaborators.alive.exists?(affiliate_user: collaborating_user)
      return { success: false, message: "The user is already a collaborator" }
    end

    collaborator = seller.collaborators.build(
      affiliate_user: collaborating_user,
      apply_to_all_products: params[:apply_to_all_products],
      dont_show_as_co_creator: params[:dont_show_as_co_creator],
      affiliate_basis_points: params[:percent_commission].presence&.to_i&.*(100),
    )

    error = nil
    params[:products].each do |product_params|
      product = seller.products.find_by_external_id(product_params[:id])
      unless product
        error = "Product not found"
        break
      end

      product_affiliate = collaborator.product_affiliates.build(product:)
      percent_commission = params[:apply_to_all_products] ? params[:percent_commission] : product_params[:percent_commission]
      product_affiliate.affiliate_basis_points = percent_commission.to_i * 100
      product_affiliate.dont_show_as_co_creator = params[:apply_to_all_products] ?
        collaborator.dont_show_as_co_creator :
        product_params[:dont_show_as_co_creator]
    end

    return { success: false, message: error } if error.present?

    if collaborator.save
      AffiliateMailer.collaborator_creation(collaborator.id).deliver_later
      { success: true }
    else
      { success: false, message: collaborator.errors.full_messages.first }
    end
  end

  private
    attr_reader :seller, :params
end
