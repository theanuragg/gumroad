import cx from "classnames";
import * as React from "react";

import { uploadPhotoId } from "$app/data/payments";
import { asyncVoid } from "$app/utils/promise";
import { assertResponseError } from "$app/utils/request";

import { showAlert } from "$app/components/server-components/Alert";

// The limit is a little less than this because the request body contains some other stuff too so this a good
// approximation for now. See https://github.com/gumroad/web/pull/19447#discussion_r664893093.
const MAX_FILE_SIZE_BYTES = 1024 * 1024 * 10; // 10 MB - Should match nginx's `client_max_body_size` configuration

type Props = {
  legend?: string;
  buttonText: string;
  idType?:
    | "company_id"
    | "additional_id"
    | "passport"
    | "visa"
    | "power_of_attorney"
    | "memorandum_of_association"
    | "proof_of_registration"
    | "company_registration_verification"
    | "bank_statement";
  onSuccess: () => void;
};

export const PhotoIdUpload = ({ legend, buttonText, idType, onSuccess }: Props) => {
  const [isFileTooLarge, setIsFileTooLarge] = React.useState(false);
  const [uploading, setUploading] = React.useState<{ filename: string } | null>(null);

  const onChange = asyncVoid(async (ev: React.ChangeEvent<HTMLInputElement>) => {
    const file = ev.target.files?.[0];
    if (!file) return;
    setUploading({ filename: file.name });
    if (file.size >= MAX_FILE_SIZE_BYTES) {
      ev.target.value = "";
      setIsFileTooLarge(true);
      setUploading(null);
    } else {
      setIsFileTooLarge(false);
      try {
        await uploadPhotoId({ file, idType });
        onSuccess();
        showAlert("Thanks! You're all set.", "success");
      } catch (e) {
        assertResponseError(e);
        ev.target.value = "";
        showAlert(e.message, "error");
      }
    }
  });

  return (
    <fieldset className={cx({ danger: isFileTooLarge })}>
      {legend ? <legend>{legend}</legend> : null}

      <label className="button primary">
        <input type="file" accept="image/*,application/pdf" onChange={onChange} disabled={uploading !== null} />

        {uploading !== null ? <>Uploading...&emsp;{uploading.filename}</> : buttonText}
      </label>
      {isFileTooLarge ? <small>File can't be larger than 10 MB</small> : null}
    </fieldset>
  );
};
