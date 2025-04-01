import cx from "classnames";
import * as React from "react";
import { createCast } from "ts-safe-cast";

import { saveUserPayoutOrientationInfo, verifyIdentityOnStripe } from "$app/data/payments";
import { asyncVoid } from "$app/utils/promise";
import { assertResponseError } from "$app/utils/request";
import { register } from "$app/utils/serverComponentUtil";

import { Button } from "$app/components/Button";
import { showAlert } from "$app/components/server-components/Alert";
import { PhotoIdUpload } from "$app/components/Settings/PhotoIdUpload";

// Matches UserComplianceInfoFields::VERIFICATION_PROMPT_FIELDS
type VerificationField =
  | "individual_tax_id"
  | "business_vat_id_number"
  | "stripe_identity_document_id"
  | "stripe_additional_document_id"
  | "stripe_company_document_id"
  | "passport"
  | "visa"
  | "power_of_attorney"
  | "memorandum_of_association"
  | "proof_of_registration"
  | "company_registration_verification"
  | "bank_account_statement"
  | "stripe_enhanced_identity_verification";

export type VerificationDetails = {
  prompt_for_full_ssn: boolean;
  prompt_for_business_vat_number: boolean;
  prompt_for_photo_id: boolean;
  prompt_for_additional_id: boolean;
  prompt_for_company_id: boolean;
  prompt_for_passport: boolean;
  prompt_for_visa: boolean;
  prompt_for_power_of_attorney: boolean;
  prompt_for_memorandum_of_association: boolean;
  prompt_for_proof_of_registration: boolean;
  prompt_for_company_registration_verification: boolean;
  prompt_for_bank_statement: boolean;
  prompt_for_enhanced_identity_verification: boolean;
  show_verification_section?: boolean;
  verification_errors: Record<VerificationField, string | null>;
  country: string | null;
};

type VerificationFormProps = { onSuccess: () => void; errorMessage: string | null };
const AskForSsn = ({ onSuccess, errorMessage }: VerificationFormProps) => {
  const [hasError, setHasError] = React.useState(false);
  const [taxId, setTaxId] = React.useState("");
  const ssnUid = React.useId();

  const onClick = asyncVoid(async () => {
    if (!taxId || taxId.length !== 11) {
      setHasError(true);
      return;
    }
    setHasError(false);
    try {
      await saveUserPayoutOrientationInfo({ user: { individual_tax_id: taxId } });
      onSuccess();
      showAlert("Thanks! You're all set.", "success");
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "warning");
    }
  });

  const formatSSN = () => {
    let val = taxId.replace(/\D/gu, ""),
      newVal = "";

    if (val.length > 3 && val.length < 6) {
      newVal += `${val.substring(0, 3)}-`;
      val = val.substring(3);
    }
    if (val.length > 5) {
      newVal += `${val.substring(0, 3)}-`;
      newVal += `${val.substring(3, 5)}-`;
      val = val.substring(5);
    }
    newVal += val;
    newVal = newVal.substring(0, 11);

    setTaxId(newVal);
  };

  return (
    <div className="paragraphs">
      <div className="warning" role="alert">
        <h4>
          {errorMessage !== null ? errorMessage : "We need some more information from you before your next payout."}
        </h4>
      </div>
      <fieldset className={cx({ danger: hasError })}>
        <legend>
          <label htmlFor={ssnUid}>Your full social security number</label>
        </legend>
        <input
          id={ssnUid}
          onChange={(evt) => {
            setHasError(false);
            setTaxId(evt.target.value);
          }}
          value={taxId}
          required
          type="text"
          placeholder="•••-••-••••"
          onKeyUp={formatSSN}
        />
        <div>
          <Button color="primary" onClick={onClick}>
            Submit
          </Button>
        </div>
      </fieldset>
    </div>
  );
};

const AskForPhotoId = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need a government-issued photo ID"}</h4>
    </div>
    <h4>Requirements</h4>
    <ul>
      <li>Image of passport (preferred) or government-issued photo ID (front and back)</li>
      <li>Must be in .png or .jpg format</li>
      <li>Must be in color and right-side up</li>
      <li>Check that all edges are visible and no parts are covered</li>
      <li>Check that all information is clearly legible</li>
    </ul>
    <p>
      Having trouble? See detailed requirements{" "}
      <a href="https://docs.stripe.com/acceptable-verification-documents?document-type=identity#select-a-country-to-view-its-requirements">
        here
      </a>
      .
    </p>
    <PhotoIdUpload
      onSuccess={onSuccess}
      legend="Government ID or passport (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForCompanyId = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need a registration document of your company"}</h4>
    </div>
    <h4>Requirements</h4>
    <ul>
      <li>Must include the business name, business address, and company registration number</li>
      <li>Must be valid and representative of up-to-date registration</li>
      <li>Must be an image or in .pdf format</li>
      <li>Check that all information is clearly legible</li>
    </ul>
    <p>
      Having trouble? See acceptable business registration documents{" "}
      <a href="https://docs.stripe.com/acceptable-verification-documents?document-type=entity#select-a-country-to-view-its-requirements">
        here
      </a>
      .
    </p>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="company_id"
      legend="Company Registration document"
      buttonText="Upload document"
    />
  </div>
);

const AskForAdditionalId = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need a document for address verification"}</h4>
    </div>
    <h4>Requirements</h4>
    <ul>
      <li>Must be a recent bank statement, utility bill, or government correspondence</li>
      <li>Must show your full name and address</li>
      <li>Must be dated within the last 6 months</li>
      <li>Must be in color and clearly legible</li>
    </ul>
    <p>
      Having trouble? See detailed requirements{" "}
      <a href="https://docs.stripe.com/acceptable-verification-documents?document-type=address#select-a-country-to-view-its-requirements">
        here
      </a>
      .
    </p>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="additional_id"
      legend="Address verification document"
      buttonText="Upload photo or scan"
    />
  </div>
);

const AskForPassport = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need your passport"}</h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="passport"
      legend="Passport (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForVisa = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need your visa"}</h4>
    </div>
    <PhotoIdUpload onSuccess={onSuccess} idType="visa" legend="Visa (maximum: 10 MB)" buttonText="Upload image" />
  </div>
);

const AskForPowerOfAttorney = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>
        {errorMessage !== null ? errorMessage : "We need a Power of Attorney document for the company representative"}
      </h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="power_of_attorney"
      legend="Power of Attorney (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForMemorandumOfAssociation = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>
        {errorMessage !== null ? errorMessage : "We need your memorandum of association (or equivalent document)"}
      </h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="memorandum_of_association"
      legend="Memorandum of Association (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForProofOfRegistration = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need a proof of registration document"}</h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="proof_of_registration"
      legend="Proof of Registration (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForCompanyRegistrationVerification = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>{errorMessage !== null ? errorMessage : "We need a document to verify company registration"}</h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="company_registration_verification"
      legend="Company Registration Verification (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForEnhancedIdentityVerification = ({
  hideHeader,
  errorMessage,
  country,
}: {
  hideHeader: boolean;
  errorMessage: string | null;
  country: string;
}) => (
  <div className="paragraphs">
    <div className="warning" role="alert" style={{ display: hideHeader ? "none" : "grid" }}>
      <h4>{errorMessage !== null ? errorMessage : "We need to perform an enhanced identity verification"}</h4>
    </div>
    <span>In order to comply with {country} regulations we require additional enhanced identity verification.</span>
    <fieldset>
      <div>
        <Button color="primary" onClick={verifyIdentityOnStripe}>
          Verify my identity
        </Button>
      </div>
    </fieldset>
  </div>
);

const AskForBankStatement = ({ onSuccess, errorMessage }: VerificationFormProps) => (
  <div className="paragraphs">
    <div className="warning" role="alert">
      <h4>
        {errorMessage !== null
          ? errorMessage
          : "We need a proof of active bank account such as a bank account statement"}
      </h4>
    </div>
    <PhotoIdUpload
      onSuccess={onSuccess}
      idType="bank_statement"
      legend="Bank Statement (maximum: 10 MB)"
      buttonText="Upload image"
    />
  </div>
);

const AskForBusinessVatNumber = ({ onSuccess, errorMessage }: VerificationFormProps) => {
  const [hasError, setHasError] = React.useState(false);
  const [taxId, setTaxId] = React.useState("");
  const vatUid = React.useId();

  const onClick = asyncVoid(async () => {
    if (!taxId || taxId.length !== 15) {
      setHasError(true);
      return;
    }
    setHasError(false);
    try {
      await saveUserPayoutOrientationInfo({ user: { business_vat_id_number: taxId } });
      onSuccess();
      showAlert("Thanks! You're all set.", "success");
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "warning");
    }
  });

  return (
    <div className="paragraphs">
      <div className="warning" role="alert">
        <h4>{errorMessage !== null ? errorMessage : "We need more information from you."}</h4>
      </div>
      <fieldset className={cx({ danger: hasError })}>
        <legend>
          <label htmlFor={vatUid}>Your business VAT ID number</label>
        </legend>
        <input
          id={vatUid}
          onChange={(evt) => {
            setHasError(false);
            setTaxId(evt.target.value);
          }}
          value={taxId}
          required
          type="text"
          placeholder="•••••••••••••••"
        />
        <div>
          <Button color="primary" onClick={onClick}>
            Submit
          </Button>
        </div>
      </fieldset>
    </div>
  );
};

export const PayoutVerification = ({
  prompt_for_full_ssn,
  prompt_for_photo_id,
  prompt_for_additional_id,
  prompt_for_company_id,
  prompt_for_passport,
  prompt_for_visa,
  prompt_for_business_vat_number,
  prompt_for_power_of_attorney,
  prompt_for_memorandum_of_association,
  prompt_for_proof_of_registration,
  prompt_for_company_registration_verification,
  prompt_for_bank_statement,
  prompt_for_enhanced_identity_verification,
  verification_errors,
  country,
}: VerificationDetails) => {
  const [showFullSsn, setShowFullSsn] = React.useState(prompt_for_full_ssn);
  const [showPhotoId, setShowPhotoId] = React.useState(prompt_for_photo_id);
  const [showAdditionalId, setShowAdditionalId] = React.useState(prompt_for_additional_id);
  const [showCompanyId, setShowCompanyId] = React.useState(prompt_for_company_id);
  const [showPassport, setShowPassport] = React.useState(prompt_for_passport);
  const [showVisa, setShowVisa] = React.useState(prompt_for_visa);
  const [showBusinessVatNumber, setShowBusinessVatNumber] = React.useState(prompt_for_business_vat_number);
  const [showPowerOfAttorney, setShowPowerOfAttorney] = React.useState(prompt_for_power_of_attorney);
  const [showMemorandumOfAssociation, setShowMemorandumOfAssociation] = React.useState(
    prompt_for_memorandum_of_association,
  );
  const [showProofOfRegistration, setShowProofOfRegistration] = React.useState(prompt_for_proof_of_registration);
  const [showCompanyRegistrationVerification, setShowCompanyRegistrationVerification] = React.useState(
    prompt_for_company_registration_verification,
  );
  const [showBankStatement, setShowBankStatement] = React.useState(prompt_for_bank_statement);
  const [showEnhancedIdentityVerification] = React.useState(prompt_for_enhanced_identity_verification);
  const showVerificationForm =
    showFullSsn ||
    showPhotoId ||
    showAdditionalId ||
    showCompanyId ||
    showBusinessVatNumber ||
    showPassport ||
    showVisa ||
    showPowerOfAttorney ||
    showMemorandumOfAssociation ||
    showProofOfRegistration ||
    showCompanyRegistrationVerification ||
    showBankStatement ||
    showEnhancedIdentityVerification;

  return showVerificationForm ? (
    <div className="paragraphs">
      {showFullSsn ? (
        <AskForSsn onSuccess={() => setShowFullSsn(false)} errorMessage={verification_errors.individual_tax_id} />
      ) : null}
      {showPhotoId ? (
        <AskForPhotoId
          onSuccess={() => setShowPhotoId(false)}
          errorMessage={verification_errors.stripe_identity_document_id}
        />
      ) : null}
      {showAdditionalId ? (
        <AskForAdditionalId
          onSuccess={() => setShowAdditionalId(false)}
          errorMessage={verification_errors.stripe_additional_document_id}
        />
      ) : null}
      {showCompanyId ? (
        <AskForCompanyId
          onSuccess={() => setShowCompanyId(false)}
          errorMessage={verification_errors.stripe_company_document_id}
        />
      ) : null}
      {showPassport ? (
        <AskForPassport onSuccess={() => setShowPassport(false)} errorMessage={verification_errors.passport} />
      ) : null}
      {showVisa ? <AskForVisa onSuccess={() => setShowVisa(false)} errorMessage={verification_errors.visa} /> : null}
      {showBusinessVatNumber ? (
        <AskForBusinessVatNumber
          onSuccess={() => setShowBusinessVatNumber(false)}
          errorMessage={verification_errors.business_vat_id_number}
        />
      ) : null}
      {showPowerOfAttorney ? (
        <AskForPowerOfAttorney
          onSuccess={() => setShowPowerOfAttorney(false)}
          errorMessage={verification_errors.power_of_attorney}
        />
      ) : null}
      {showMemorandumOfAssociation ? (
        <AskForMemorandumOfAssociation
          onSuccess={() => setShowMemorandumOfAssociation(false)}
          errorMessage={verification_errors.memorandum_of_association}
        />
      ) : null}
      {showProofOfRegistration ? (
        <AskForProofOfRegistration
          onSuccess={() => setShowProofOfRegistration(false)}
          errorMessage={verification_errors.proof_of_registration}
        />
      ) : null}
      {showCompanyRegistrationVerification ? (
        <AskForCompanyRegistrationVerification
          onSuccess={() => setShowCompanyRegistrationVerification(false)}
          errorMessage={verification_errors.company_registration_verification}
        />
      ) : null}
      {showBankStatement ? (
        <AskForBankStatement
          onSuccess={() => setShowBankStatement(false)}
          errorMessage={verification_errors.bank_account_statement}
        />
      ) : null}
      {showEnhancedIdentityVerification && (country === "Singapore" || country === "Canada") ? (
        <AskForEnhancedIdentityVerification
          hideHeader={showPhotoId || showAdditionalId || showCompanyId}
          errorMessage={verification_errors.stripe_enhanced_identity_verification}
          country={country}
        />
      ) : null}
    </div>
  ) : (
    <div role="status" className="success">
      You're all set!
    </div>
  );
};

export default register({ component: PayoutVerification, propParser: createCast() });
