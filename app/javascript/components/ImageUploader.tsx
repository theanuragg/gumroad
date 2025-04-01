import * as React from "react";

import FileUtils from "$app/utils/file";

import { Button } from "$app/components/Button";
import { Icon } from "$app/components/Icons";
import { Progress } from "$app/components/Progress";
import { showAlert } from "$app/components/server-components/Alert";

export const ImageUploader = ({
  id,
  helpText,
  imageUrl,
  allowedExtensions,
  onSelectFile,
  onRemove,
  imageAlt,
  disabled,
  defaultImageUrl,
}: {
  id?: string;
  helpText: string;
  imageUrl: string | null;
  defaultImageUrl?: string;
  allowedExtensions: string[];
  onSelectFile: (file: File) => Promise<void>;
  onRemove: () => void;
  imageAlt: string;
  disabled?: boolean;
}) => {
  const [uploading, setUploading] = React.useState(false);

  const overlayColor = "rgb(var(--filled) / calc(1 - var(--disabled-opacity)))";
  const background =
    defaultImageUrl && `linear-gradient(${overlayColor}, ${overlayColor}), url(${defaultImageUrl}) center / cover`;

  return (
    <div className="image-uploader">
      {uploading ? (
        <div className="placeholder">
          <Progress width="2rem" />
        </div>
      ) : imageUrl == null ? (
        <div className="placeholder" style={{ background }}>
          <label className="button primary">
            <input
              type="file"
              id={id}
              accept={allowedExtensions.map((ext) => `.${ext}`).join(",")}
              onChange={(evt) => {
                const file = evt.target.files?.[0];
                if (!file) return;
                if (!FileUtils.isFileNameExtensionAllowed(file.name, allowedExtensions))
                  return showAlert("Invalid file type.", "error");

                setUploading(true);
                void onSelectFile(file).finally(() => setUploading(false));
              }}
              disabled={disabled}
            />
            <Icon name="upload-fill" />
            Upload
          </label>
        </div>
      ) : (
        <figure>
          <img alt={imageAlt} src={imageUrl} />
          <Button color="primary" small className="remove" aria-label="Remove" onClick={onRemove} disabled={disabled}>
            <Icon name="trash2" />
          </Button>
        </figure>
      )}
      <div>{helpText}</div>
    </div>
  );
};
