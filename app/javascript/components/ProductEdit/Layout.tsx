import * as React from "react";
import { Link, useMatches, useNavigate } from "react-router-dom";

import { saveProduct } from "$app/data/product_edit";
import { setProductPublished } from "$app/data/publish_product";
import { assertResponseError } from "$app/utils/request";

import { Button, NavigationButton } from "$app/components/Button";
import { CopyToClipboard } from "$app/components/CopyToClipboard";
import { useCurrentSeller } from "$app/components/CurrentSeller";
import { useDomains } from "$app/components/DomainSettings";
import { Icon } from "$app/components/Icons";
import { Preview } from "$app/components/Preview";
import { useImageUploadSettings } from "$app/components/RichTextEditor";
import { showAlert } from "$app/components/server-components/Alert";
import { SubtitleFile } from "$app/components/SubtitleList/Row";
import { useRefToLatest } from "$app/components/useRefToLatest";
import { WithTooltip } from "$app/components/WithTooltip";

import { FileEntry, useProductEditContext } from "./state";

export const useProductUrl = (params = {}) => {
  const { product, uniquePermalink } = useProductEditContext();
  const currentSeller = useCurrentSeller();
  const { appDomain } = useDomains();
  return product.native_type === "coffee" && currentSeller
    ? Routes.custom_domain_coffee_url({ host: currentSeller.subdomain, ...params })
    : Routes.short_link_url(product.custom_permalink ?? uniquePermalink, {
        host: currentSeller?.subdomain ?? appDomain,
        ...params,
      });
};

export const Layout = ({
  children,
  preview,
  isLoading = false,
  headerActions,
}: {
  children: React.ReactNode;
  preview?: React.ReactNode;
  isLoading?: boolean;
  headerActions?: React.ReactNode;
}) => {
  const { id, product, updateProduct, uniquePermalink, saving, save } = useProductEditContext();
  const rootPath = `/products/${uniquePermalink}/edit`;

  const url = useProductUrl();
  const checkoutUrl = useProductUrl({ wanted: true });

  const [match] = useMatches();
  const tab = match?.handle ?? "product";

  const navigate = useRefToLatest(useNavigate());

  const [isPublishing, setIsPublishing] = React.useState(false);
  const setPublished = async (published: boolean) => {
    try {
      setIsPublishing(true);
      await saveProduct(uniquePermalink, id, product);
      await setProductPublished(uniquePermalink, published);
      updateProduct({ is_published: published });
      showAlert(published ? "Published!" : "Unpublished!", "success");
      if (tab === "share") {
        if (product.native_type === "coffee") navigate.current(rootPath);
        else navigate.current(`${rootPath}/content`);
      }
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "error", { html: true });
    }
    setIsPublishing(false);
  };

  const isUploadingFile = (file: FileEntry | SubtitleFile) =>
    file.status.type === "unsaved" && file.status.uploadStatus.type === "uploading";
  const isUploadingFiles =
    product.public_files.some((f) => f.status?.type === "unsaved" && f.status.uploadStatus.type === "uploading") ||
    product.files.some((file) => isUploadingFile(file) || file.subtitle_files.some(isUploadingFile));
  const imageSettings = useImageUploadSettings();
  const isUploadingFilesOrImages = isLoading || isUploadingFiles || !!imageSettings?.isUploading;
  const isBusy = isUploadingFilesOrImages || saving || isPublishing;
  const saveButtonTooltip = isUploadingFiles
    ? "Files are still uploading..."
    : isUploadingFilesOrImages
      ? "Images are still uploading..."
      : isBusy
        ? "Please wait..."
        : undefined;

  React.useEffect(() => {
    if (!isUploadingFilesOrImages) return;

    const beforeUnload = (e: BeforeUnloadEvent) => e.preventDefault();

    window.addEventListener("beforeunload", beforeUnload);

    return () => window.removeEventListener("beforeunload", beforeUnload);
  }, [isUploadingFilesOrImages]);

  const saveButton = (
    <WithTooltip tip={saveButtonTooltip}>
      <Button color="primary" disabled={isBusy} onClick={() => void save()}>
        {saving ? "Saving changes..." : "Save changes"}
      </Button>
    </WithTooltip>
  );

  const onTabClick = (e: React.MouseEvent<HTMLAnchorElement>, callback?: () => void) => {
    const message = isUploadingFiles
      ? "Some files are still uploading, please wait..."
      : isUploadingFilesOrImages
        ? "Some images are still uploading, please wait..."
        : undefined;

    if (message) {
      e.preventDefault();
      showAlert(message, "warning");
      return;
    }

    callback?.();
  };

  const isCoffee = product.native_type === "coffee";

  return (
    <>
      {/* TODO: remove this legacy uploader stuff */}
      <form hidden data-id={uniquePermalink} id="edit-link-basic-form" />
      <header className="sticky-top">
        <h1>{product.name || "Untitled"}</h1>
        <div className="actions">
          {product.is_published ? (
            <>
              <Button disabled={isBusy} onClick={() => void setPublished(false)}>
                {isPublishing ? "Unpublishing..." : "Unpublish"}
              </Button>
              {saveButton}
              <CopyToClipboard text={url} copyTooltip="Copy product URL">
                <Button>
                  <Icon name="link" />
                </Button>
              </CopyToClipboard>
              <CopyToClipboard text={checkoutUrl} copyTooltip="Copy checkout URL">
                <Button>
                  <Icon name="cart-plus" />
                </Button>
              </CopyToClipboard>
            </>
          ) : tab === "product" && !isCoffee ? (
            <Button
              color="primary"
              disabled={isBusy}
              onClick={() => void save().then(() => navigate.current(`${rootPath}/content`))}
            >
              {saving ? "Saving changes..." : "Save and continue"}
            </Button>
          ) : (
            <>
              {saveButton}
              <WithTooltip tip={saveButtonTooltip}>
                <Button
                  color="accent"
                  disabled={isBusy}
                  onClick={() => void setPublished(true).then(() => navigate.current(`${rootPath}/share`))}
                >
                  {isPublishing ? "Publishing..." : "Publish and continue"}
                </Button>
              </WithTooltip>
            </>
          )}
        </div>
        <div role="tablist" style={{ gridColumn: 1 }}>
          <Link to={rootPath} role="tab" aria-selected={tab === "product"} onClick={onTabClick}>
            Product
          </Link>
          {!isCoffee ? (
            <Link to={`${rootPath}/content`} role="tab" aria-selected={tab === "content"} onClick={onTabClick}>
              Content
            </Link>
          ) : null}
          <Link
            to={`${rootPath}/share`}
            role="tab"
            aria-selected={tab === "share"}
            onClick={(evt) => {
              onTabClick(evt, () => {
                if (!product.is_published) {
                  evt.preventDefault();
                  showAlert(
                    "Not yet! You've got to publish your awesome product before you can share it with your audience and the world.",
                    "warning",
                  );
                }
              });
            }}
          >
            Share
          </Link>
        </div>
        {headerActions}
      </header>
      {children}
      {preview ? (
        <aside aria-label="Preview">
          <header>
            <h2>Preview</h2>
            <WithTooltip tip="Preview">
              <NavigationButton
                aria-label="Preview"
                disabled={isBusy}
                href={url}
                onClick={(evt) => {
                  evt.preventDefault();
                  void save().then(() => window.open(url, "_blank"));
                }}
              >
                <Icon name="arrow-diagonal-up-right" />
              </NavigationButton>
            </WithTooltip>
          </header>
          <Preview
            scaleFactor={0.4}
            style={{
              border: "var(--border)",
              backgroundColor: "rgb(var(--filled))",
              borderRadius: "var(--border-radius-2)",
            }}
          >
            {preview}
          </Preview>
        </aside>
      ) : null}
    </>
  );
};
