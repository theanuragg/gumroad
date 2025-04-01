import ReactOnRails from "react-on-rails";

import BasePage from "$app/utils/base_page";

import DiscoverProductPage from "$app/components/server-components/Discover/ProductPage";
import ProductPage from "$app/components/server-components/Product";
import ProductCartItemsCountPage from "$app/components/server-components/Product/CartItemsCountPage";
import ProductIframePage from "$app/components/server-components/Product/IframePage";
import ProfileCoffeePage from "$app/components/server-components/Profile/CoffeePage";
import ProfileProductPage from "$app/components/server-components/Profile/ProductPage";
import PurchaseProductPage from "$app/components/server-components/Purchase/ProductPage";

BasePage.initialize();
ReactOnRails.register({
  DiscoverProductPage,
  ProfileCoffeePage,
  ProfileProductPage,
  PurchaseProductPage,
  ProductPage,
  ProductCartItemsCountPage,
  ProductIframePage,
});
