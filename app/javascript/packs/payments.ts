import ReactOnRails from "react-on-rails";

import BasePage from "$app/utils/base_page";

import CountrySelectionModal from "$app/components/server-components/CountrySelectionModal";
import PayoutCreditCard from "$app/components/server-components/PayoutPage/CreditCard";
import PayoutVerification from "$app/components/server-components/PayoutPage/Verification";
import CreditCardForm from "$app/components/server-components/Settings/CreditCardForm";
import PaymentsSettingsPage from "$app/components/server-components/Settings/PaymentsPage";
import TaxesCollectionModal from "$app/components/server-components/TaxesCollectionModal";

BasePage.initialize();

ReactOnRails.register({
  PaymentsSettingsPage,
  CountrySelectionModal,
  PayoutVerification,
  PayoutCreditCard,
  TaxesCollectionModal,
  CreditCardForm,
});
