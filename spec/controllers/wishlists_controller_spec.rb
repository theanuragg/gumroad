# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorize_called"

describe WishlistsController do
  render_views

  let(:user) { create(:user) }
  let(:wishlist) { create(:wishlist, user:) }

  describe "GET index" do
    before do
      sign_in(user)
      wishlist
    end

    it_behaves_like "authorize called for action", :get, :index do
      let(:record) { Wishlist }
    end

    context "when html is requested" do
      it "renders non-deleted wishlists for the current seller" do
        wishlist.mark_deleted!
        alive_wishlist = create(:wishlist, user:)
        create(:wishlist)

        get :index

        expect(response).to be_successful
        expect(assigns(:wishlists_props)).to contain_exactly(a_hash_including(id: alive_wishlist.external_id))
      end
    end

    context "when json is requested" do
      it "returns wishlists with the given ids" do
        wishlist2 = create(:wishlist, user:)
        create(:wishlist, user:)

        get :index, format: :json, params: { ids: [wishlist.external_id, wishlist2.external_id] }

        expect(response).to be_successful
        expect(response.parsed_body).to eq(WishlistPresenter.cards_props(wishlists: Wishlist.where(id: [wishlist.id, wishlist2.id]), pundit_user: controller.pundit_user, layout: Product::Layout::PROFILE).as_json)
      end
    end
  end

  describe "POST create" do
    before do
      sign_in user
    end

    it_behaves_like "authorize called for action", :post, :create do
      let(:record) { Wishlist }
    end

    it "creates a wishlist with a default name" do
      expect { post :create }.to change(Wishlist, :count).by(1)

      expect(Wishlist.last).to have_attributes(name: "Wishlist 1", user:)
      expect(response.parsed_body).to eq(
        "wishlist" => {
          "id" => Wishlist.last.external_id,
          "name" => "Wishlist 1"
        }
      )

      expect { post :create }.to change(Wishlist, :count).by(1)

      expect(Wishlist.last).to have_attributes(name: "Wishlist 2", user:)
    end
  end

  describe "GET show" do
    it "finds the wishlist from the URL suffix" do
      request.host = URI.parse(user.subdomain_with_protocol).host
      get :show, params: { id: wishlist.url_slug }

      expect(response).to be_successful
      expect(assigns(:wishlist_presenter)).to be_a(WishlistPresenter)
      expect(assigns(:wishlist_presenter).wishlist).to eq wishlist
    end

    context "when the wishlist is deleted" do
      before { wishlist.mark_deleted! }

      it "returns 404" do
        request.host = URI.parse(user.subdomain_with_protocol).host
        expect { get :show, params: { id: wishlist.url_slug } }.to raise_error(ActionController::RoutingError, "Not Found")
      end
    end
  end

  describe "PUT update" do
    before do
      sign_in(user)
    end

    it_behaves_like "authorize called for action", :put, :update do
      let(:record) { Wishlist }
      let(:request_params) { { id: wishlist.external_id, wishlist: { name: "New Name" } } }
    end

    it "updates the wishlist name and description" do
      put :update, params: { id: wishlist.external_id, wishlist: { name: "New Name", description: "New Description" } }

      expect(response).to be_successful
      expect(wishlist.reload.name).to eq "New Name"
      expect(wishlist.description).to eq "New Description"
    end

    it "renders validation errors" do
      expect do
        put :update, params: { id: wishlist.external_id, wishlist: { name: "" } }
      end.not_to change { wishlist.reload.name }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "Name can't be blank")
    end
  end

  describe "DELETE destroy" do
    before do
      sign_in(user)
    end

    it_behaves_like "authorize called for action", :delete, :destroy do
      let(:record) { wishlist }
      let(:request_params) { { id: wishlist.external_id } }
    end

    it "marks the wishlist and followers as deleted" do
      wishlist_follower = create(:wishlist_follower, wishlist:)

      delete :destroy, params: { id: wishlist.external_id }

      expect(response).to be_successful
      expect(wishlist.reload).to be_deleted
      expect(wishlist_follower.reload).to be_deleted
    end
  end
end
