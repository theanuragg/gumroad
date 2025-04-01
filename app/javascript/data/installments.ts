import { cast } from "ts-safe-cast";

import { CurrencyCode } from "$app/utils/currency";
import { request, ResponseError } from "$app/utils/request";

import { FileItem } from "$app/components/EmailAttachments";

export type Installment = {
  external_id?: string;
  name: string;
  message: string;
  published_at: string | null;
  updated_at: string;
  stream_only: boolean;
  streamable: boolean;
  send_emails: boolean;
  shown_on_profile: boolean;
  installment_type: string;
  bought_products?: string[];
  not_bought_products?: string[];
  bought_variants?: string[];
  not_bought_variants?: string[];
  unique_permalink?: string;
  variant_external_id?: string;
  affiliate_products?: string[];
  paid_more_than_cents: number | null;
  paid_less_than_cents: number | null;
  created_after?: string;
  created_before?: string;
  bought_from?: string;
  allow_comments: boolean;
  full_url: string;
  has_been_blasted: boolean;
  files: FileItem[];
  shown_in_profile_sections?: string[];
};

export type SavedInstallment = Installment & {
  external_id: string;
  shown_in_profile_sections: string[];
};

export type PublishedInstallment = SavedInstallment & {
  external_id: string;
  sent_count: number | null;
  click_count: number;
  click_rate: number | null;
  clicked_urls: { url: string; count: number }[];
  open_count: number;
  open_rate: number | null;
  view_count: number | null;
  published_at: string;
};

export type ScheduledInstallment = SavedInstallment & {
  external_id: string;
  recipient_description: string | null;
  to_be_published_at: string;
};

export type DraftInstallment = SavedInstallment & {
  external_id: string;
  recipient_description: string | null;
};

export type Pagination = {
  count: number;
  next: number | null;
};

export type AudienceType = "everyone" | "customers" | "followers" | "affiliates";

export type InstallmentFormContext = {
  audience_types: AudienceType[];
  products: { permalink: string; name: string; archived: boolean; variants: { id: string; name: string }[] }[];
  affiliate_products: { permalink: string; name: string; archived: boolean }[];
  timezone: string;
  currency_type: CurrencyCode;
  countries: string[];
  profile_sections: { id: string; name: string | null }[];
  has_scheduled_emails: boolean;
  aws_access_key_id: string;
  s3_url: string;
  user_id: string;
  allow_comments_by_default: boolean;
};

export function getPublishedInstallments({ page, query }: { page: number; query: string }) {
  const abort = new AbortController();
  const response = request({
    method: "GET",
    accept: "json",
    url: Routes.internal_installments_path({ params: { type: "published", page, query } }),
    abortSignal: abort.signal,
  })
    .then((res) => {
      if (!res.ok) throw new ResponseError();
      return res.json();
    })
    .then((json) => cast<{ installments: PublishedInstallment[]; pagination: Pagination }>(json));

  return {
    response,
    cancel: () => abort.abort(),
  };
}

export function getScheduledInstallments({ page, query }: { page: number; query: string }) {
  const abort = new AbortController();
  const response = request({
    method: "GET",
    accept: "json",
    url: Routes.internal_installments_path({ params: { type: "scheduled", page, query } }),
    abortSignal: abort.signal,
  })
    .then((res) => {
      if (!res.ok) throw new ResponseError();
      return res.json();
    })
    .then((json) => cast<{ installments: ScheduledInstallment[]; pagination: Pagination }>(json));

  return {
    response,
    cancel: () => abort.abort(),
  };
}

export function getDraftInstallments({ page, query }: { page: number; query: string }) {
  const abort = new AbortController();
  const response = request({
    method: "GET",
    accept: "json",
    url: Routes.internal_installments_path({ params: { type: "draft", page, query } }),
    abortSignal: abort.signal,
  })
    .then((res) => {
      if (!res.ok) throw new ResponseError();
      return res.json();
    })
    .then((json) => cast<{ installments: DraftInstallment[]; pagination: Pagination }>(json));

  return {
    response,
    cancel: () => abort.abort(),
  };
}

export async function getAudienceCount(externalId: string) {
  const response = await request({
    method: "GET",
    accept: "json",
    url: Routes.internal_installment_audience_count_path(externalId),
  });

  if (!response.ok) throw new ResponseError();
  return cast<{ count: number }>(await response.json());
}

type RecipientCountRequestPayload = {
  paid_more_than_cents: number | null;
  paid_less_than_cents: number | null;
  bought_from: string | null;
  installment_type: string;
  created_after: string;
  created_before: string;
  bought_products: string[] | null;
  bought_variants: string[] | null;
  not_bought_products: string[] | null;
  not_bought_variants: string[] | null;
  affiliate_products: string[] | null;
};
export function getRecipientCount(requestPayload: RecipientCountRequestPayload) {
  const abort = new AbortController();
  const response = request({
    method: "GET",
    accept: "json",
    url: Routes.internal_installment_recipient_count_path(requestPayload),
    abortSignal: abort.signal,
  })
    .then((res) => {
      if (!res.ok) throw new ResponseError();
      return res.json();
    })
    .then((json) => cast<{ recipient_count: number; audience_count: number }>(json));

  return {
    response,
    cancel: () => abort.abort(),
  };
}

export async function deleteInstallment(externalId: string) {
  const response = await request({
    method: "DELETE",
    accept: "json",
    url: Routes.internal_installment_path(externalId),
  });

  if (!response.ok) throw new ResponseError();
  const responseData = cast<{ success: true } | { success: false; message: string }>(await response.json());
  if (!responseData.success) throw new ResponseError(responseData.message);
  return responseData;
}

export async function getNewInstallment(copy_from: string | null = null) {
  const response = await request({
    method: "GET",
    accept: "json",
    url: Routes.new_internal_installment_path({ copy_from }),
  });
  if (!response.ok) throw new ResponseError();
  return cast<{ context: InstallmentFormContext; installment: Omit<Installment, "external_id"> | null }>(
    await response.json(),
  );
}

type SaveInstallmentPayload = {
  installment: {
    name: string;
    message: string;
    files: {
      external_id: string;
      position: number;
      url: string;
      stream_only: boolean;
      subtitle_files: { language: string; url: string }[];
    }[];
    link_id: string | null;
    paid_more_than_cents: number | null;
    paid_less_than_cents: number | null;
    bought_from: string | null;
    installment_type: string;
    created_after: string;
    created_before: string;
    bought_products: string[] | null;
    bought_variants: string[] | null;
    not_bought_products: string[] | null;
    not_bought_variants: string[] | null;
    affiliate_products: string[] | null;
    send_emails: boolean;
    shown_on_profile: boolean;
    allow_comments: boolean;
    shown_in_profile_sections: string[];
  };
  variant_external_id: string | null;
  send_preview_email: boolean;
  to_be_published_at: Date | null;
  publish: boolean;
};
export async function createInstallment(payload: SaveInstallmentPayload) {
  const response = await request({
    method: "POST",
    accept: "json",
    url: Routes.internal_installments_path(),
    data: payload,
  });
  if (!response.ok) throw new ResponseError(cast<{ message: string }>(await response.json()).message);
  return cast<{ installment_id: string; full_url: string }>(await response.json());
}

export async function updateInstallment(externalId: string, payload: SaveInstallmentPayload) {
  const response = await request({
    method: "PUT",
    accept: "json",
    url: Routes.internal_installment_path(externalId),
    data: payload,
  });
  if (!response.ok) throw new ResponseError(cast<{ message: string }>(await response.json()).message);
  return cast<{ installment_id: string; full_url: string }>(await response.json());
}

export async function getEditInstallment(externalId: string) {
  const response = await request({
    method: "GET",
    accept: "json",
    url: Routes.edit_internal_installment_path(externalId),
  });
  if (!response.ok) throw new ResponseError();
  return cast<{ context: InstallmentFormContext; installment: SavedInstallment }>(await response.json());
}

export async function previewInstallment(externalId: string) {
  const response = await request({
    method: "POST",
    accept: "json",
    url: Routes.internal_installment_preview_email_path(externalId),
  });

  if (!response.ok) throw new ResponseError(cast<{ message: string }>(await response.json()).message);
}
