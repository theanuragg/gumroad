import { cast } from "ts-safe-cast";

import { asyncVoid } from "$app/utils/promise";
import { request, ResponseError } from "$app/utils/request";

export const saveUserPayoutOrientationInfo = async (data: {
  user: { individual_tax_id: string } | { business_vat_id_number: string };
}): Promise<void> => {
  const response = await request({
    method: "PUT",
    url: Routes.settings_payments_path(),
    accept: "json",
    data,
  });

  const parsedResponse = cast<{ success: true } | { success: false; error_message: string }>(await response.json());
  if (!parsedResponse.success) throw new ResponseError(parsedResponse.error_message);
};

export const disconnectStripeAccount = async (): Promise<void> => {
  const response = await request({
    method: "POST",
    url: Routes.disconnect_settings_stripe_path(),
    accept: "json",
  });

  const parsedResponse = cast<{ success: true } | { success: false; error_message: string }>(await response.json());
  if (!parsedResponse.success) throw new ResponseError(parsedResponse.error_message);
};

export const disconnectPaypalAccount = async () => {
  const response = await request({
    method: "POST",
    url: Routes.disconnect_paypal_path(),
    accept: "json",
  });

  const parsedResponse = cast<{ success: boolean }>(await response.json());
  if (!parsedResponse.success) throw new ResponseError();
};

type UploadPhotoIdArgs = {
  file: File;
  idType?:
    | "company_id"
    | "additional_id"
    | "passport"
    | "visa"
    | "power_of_attorney"
    | "memorandum_of_association"
    | "bank_statement"
    | "proof_of_registration"
    | "company_registration_verification"
    | undefined;
};
export const uploadPhotoId = async ({ file, idType }: UploadPhotoIdArgs): Promise<void> => {
  const formData = new FormData();
  formData.append("photo_id", file);
  if (idType === "company_id") formData.append("is_company_id", "true");
  if (idType === "additional_id") formData.append("is_additional_id", "true");
  if (idType === "passport") formData.append("is_passport", "true");
  if (idType === "visa") formData.append("is_visa", "true");
  if (idType === "power_of_attorney") formData.append("is_power_of_attorney", "true");
  if (idType === "memorandum_of_association") formData.append("is_memorandum_of_association", "true");
  if (idType === "bank_statement") formData.append("is_bank_statement", "true");
  if (idType === "proof_of_registration") formData.append("is_proof_of_registration", "true");
  if (idType === "company_registration_verification") formData.append("is_company_registration_verification", "true");

  const response = await request({
    method: "POST",
    accept: "json",
    url: Routes.settings_payments_verify_document_path(),
    data: formData,
  });
  if (!response.ok) throw new ResponseError("Something went wrong. Please check the requirements and try again.");
  const responseData = cast<{ success: true } | { success: false; error: string }>(await response.json());
  if (!responseData.success) throw new ResponseError(responseData.error);
};

export const verifyIdentityOnStripe = asyncVoid(async () => {
  const response = await request({
    method: "POST",
    url: Routes.settings_payments_verify_identity_path(),
    accept: "json",
  });
  const responseData = cast<{ success: true; redirect_url: string } | { success: false; error: string }>(
    await response.json(),
  );
  if (response.ok && responseData.success) {
    window.location.href = responseData.redirect_url;
  }
});
