import "core-js/actual/url";
import "abortcontroller-polyfill/dist/abortcontroller-polyfill-only";
import "whatwg-fetch";
import ReactOnRails from "react-on-rails";

import AdminNav from "$app/components/server-components/Admin/Nav";
import AffiliatedPage from "$app/components/server-components/AffiliatedPage";
import AffiliateRequestPage from "$app/components/server-components/AffiliateRequestPage";
import AffiliatesPage from "$app/components/server-components/AffiliatesPage";
import Alert from "$app/components/server-components/Alert";
import AnalyticsPage from "$app/components/server-components/AnalyticsPage";
import ArchivedProductsPage from "$app/components/server-components/ArchivedProductsPage";
import AudienceCustomersPage from "$app/components/server-components/Audience/CustomersPage";
import AudiencePage from "$app/components/server-components/AudiencePage";
import BalancePage from "$app/components/server-components/BalancePage";
import BundleEditPage from "$app/components/server-components/BundleEditPage";
import DiscountsPage from "$app/components/server-components/CheckoutDashboard/DiscountsPage";
import FormPage from "$app/components/server-components/CheckoutDashboard/FormPage";
import UpsellsPage from "$app/components/server-components/CheckoutDashboard/UpsellsPage";
import CheckoutPage from "$app/components/server-components/CheckoutPage";
import CollaboratorsPage from "$app/components/server-components/CollaboratorsPage";
import CollabsPage from "$app/components/server-components/CollabsPage";
import CountrySelectionModal from "$app/components/server-components/CountrySelectionModal";
import CustomersDownloadPopover from "$app/components/server-components/CustomersPage/DownloadPopover";
import CustomersFilterPopover from "$app/components/server-components/CustomersPage/FilterPopover";
import DashboardPage from "$app/components/server-components/DashboardPage";
import DeveloperWidgetsPage from "$app/components/server-components/Developer/WidgetsPage";
import Discover from "$app/components/server-components/Discover";
import DiscoverProductPage from "$app/components/server-components/Discover/ProductPage";
import DiscoverWishlistPage from "$app/components/server-components/Discover/WishlistPage";
import DownloadPageWithContent from "$app/components/server-components/DownloadPage/WithContent";
import DownloadPageWithoutContent from "$app/components/server-components/DownloadPage/WithoutContent";
import EmailsPage from "$app/components/server-components/EmailsPage";
import FollowersPage from "$app/components/server-components/FollowersPage";
import GenerateInvoiceConfirmationPage from "$app/components/server-components/GenerateInvoiceConfirmationPage";
import GenerateInvoicePage from "$app/components/server-components/GenerateInvoicePage";
import LibraryPage from "$app/components/server-components/LibraryPage";
import LoginPage from "$app/components/server-components/LoginPage";
import Nav from "$app/components/server-components/Nav";
import NewProductPage from "$app/components/server-components/NewProductPage";
import PayoutCreditCard from "$app/components/server-components/PayoutPage/CreditCard";
import PayoutVerification from "$app/components/server-components/PayoutPage/Verification";
import PdfReaderPage from "$app/components/server-components/PdfReaderPage";
import ProductPage from "$app/components/server-components/Product";
import ProductIframePage from "$app/components/server-components/Product/IframePage";
import ProductEditPage from "$app/components/server-components/ProductEditPage";
import ProductsDashboardPage from "$app/components/server-components/ProductsDashboardPage";
import Profile from "$app/components/server-components/Profile";
import ProfileCoffeePage from "$app/components/server-components/Profile/CoffeePage";
import ProfilePostPage from "$app/components/server-components/Profile/PostPage";
import ProfileProductPage from "$app/components/server-components/Profile/ProductPage";
import ProfileSettingsPage from "$app/components/server-components/Profile/SettingsPage";
import ProfileWishlistPage from "$app/components/server-components/Profile/WishlistPage";
import PublicChargePage from "$app/components/server-components/Public/ChargePage";
import PublicLicenseKeyPage from "$app/components/server-components/Public/LicenseKeyPage";
import DisputeEvidencePage from "$app/components/server-components/Purchase/DisputeEvidencePage";
import PurchaseProductPage from "$app/components/server-components/Purchase/ProductPage";
import SubscribeReviewReminders from "$app/components/server-components/ReviewReminders/SubscribeReviewReminders";
import UnsubscribeReviewReminders from "$app/components/server-components/ReviewReminders/UnsubscribeReviewReminders";
import ReviewsPage from "$app/components/server-components/ReviewsPage";
import AdvancedSettingsPage from "$app/components/server-components/Settings/AdvancedPage";
import ApplicationEditPage from "$app/components/server-components/Settings/AdvancedPage/EditApplicationPage";
import AuthorizedApplicationsSettingsPage from "$app/components/server-components/Settings/AuthorizedApplicationsPage";
import MainSettingsPage from "$app/components/server-components/Settings/MainPage";
import PasswordSettingsPage from "$app/components/server-components/Settings/PasswordPage";
import PaymentsSettingsPage from "$app/components/server-components/Settings/PaymentsPage";
import TeamSettingsPage from "$app/components/server-components/Settings/TeamPage";
import ThirdPartyAnalyticsSettingsPage from "$app/components/server-components/Settings/ThirdPartyAnalyticsPage";
import SignupPage from "$app/components/server-components/SignupPage";
import SubscribePage from "$app/components/server-components/SubscribePage";
import SubscribePreview from "$app/components/server-components/SubscribePreview";
import SubscriptionManager from "$app/components/server-components/SubscriptionManager";
import SubscriptionManagerMagicLink from "$app/components/server-components/SubscriptionManagerMagicLink";
import TaxesCollectionModal from "$app/components/server-components/TaxesCollectionModal";
import TwoFactorAuthenticationPage from "$app/components/server-components/TwoFactorAuthenticationPage";
import UtmLinksPage from "$app/components/server-components/UtmLinksPage";
import VideoStreamPlayer from "$app/components/server-components/VideoStreamPlayer";
import WishlistPage from "$app/components/server-components/WishlistPage";
import WishlistsFollowingPage from "$app/components/server-components/WishlistsFollowingPage";
import WishlistsPage from "$app/components/server-components/WishlistsPage";
import WorkflowsPage from "$app/components/server-components/WorkflowsPage";

ReactOnRails.register({
  AdminNav,
  AdvancedSettingsPage,
  AffiliatedPage,
  AffiliateRequestPage,
  AffiliatesPage,
  Alert,
  AnalyticsPage,
  ApplicationEditPage,
  ArchivedProductsPage,
  AudienceCustomersPage,
  AudiencePage,
  AuthorizedApplicationsSettingsPage,
  BalancePage,
  BundleEditPage,
  CheckoutPage,
  CollaboratorsPage,
  CollabsPage,
  CountrySelectionModal,
  CustomersDownloadPopover,
  CustomersFilterPopover,
  DashboardPage,
  DeveloperWidgetsPage,
  DiscountsPage,
  Discover,
  DiscoverProductPage,
  DiscoverWishlistPage,
  DisputeEvidencePage,
  DownloadPageWithContent,
  DownloadPageWithoutContent,
  EmailsPage,
  FollowersPage,
  FormPage,
  GenerateInvoiceConfirmationPage,
  GenerateInvoicePage,
  LibraryPage,
  LoginPage,
  MainSettingsPage,
  Nav,
  NewProductPage,
  PasswordSettingsPage,
  PaymentsSettingsPage,
  PayoutCreditCard,
  PayoutVerification,
  PdfReaderPage,
  ProductEditPage,
  ProductIframePage,
  PurchaseProductPage,
  ProductPage,
  ProductsDashboardPage,
  Profile,
  ProfileCoffeePage,
  ProfilePostPage,
  ProfileProductPage,
  ProfileSettingsPage,
  ProfileWishlistPage,
  PublicChargePage,
  PublicLicenseKeyPage,
  ReviewsPage,
  SignupPage,
  SubscribePage,
  SubscribePreview,
  SubscribeReviewReminders,
  UnsubscribeReviewReminders,
  SubscriptionManager,
  SubscriptionManagerMagicLink,
  TaxesCollectionModal,
  TeamSettingsPage,
  ThirdPartyAnalyticsSettingsPage,
  TwoFactorAuthenticationPage,
  UpsellsPage,
  VideoStreamPlayer,
  WishlistPage,
  WishlistsFollowingPage,
  WishlistsPage,
  WorkflowsPage,
  UtmLinksPage,
});
