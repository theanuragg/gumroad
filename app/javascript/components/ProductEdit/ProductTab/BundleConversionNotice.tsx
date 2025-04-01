import * as React from "react";

import { Button, NavigationButton } from "$app/components/Button";
import { Modal } from "$app/components/Modal";
import { useProductEditContext } from "$app/components/ProductEdit/state";

const BUNDLE_WORDS = ["bundle", "pack"];

export const BundleConversionNotice = () => {
  const { product, id } = useProductEditContext();

  const showNotice = BUNDLE_WORDS.some((word) => product.name.toLowerCase().includes(word.toLowerCase()));

  const [isModalOpen, setIsModalOpen] = React.useState(false);

  if (!showNotice || product.native_type === "membership" || product.variants.length) return null;

  return (
    <>
      <div role="status" className="info">
        <div className="paragraphs">
          <p>
            <strong>Looks like this product could be a great bundle!</strong> With bundles, your customers can get
            access to multiple products at once at a discounted price, without the need to duplicate content or
            workflows.
          </p>
          <div>
            <Button color="primary" small onClick={() => setIsModalOpen(true)}>
              Switch to bundle
            </Button>
          </div>
        </div>
      </div>
      <Modal
        open={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={`Transform "${product.name}" into a bundle?`}
        footer={
          <>
            <Button onClick={() => setIsModalOpen(false)}>No, cancel</Button>
            <NavigationButton href={`${Routes.bundle_path(id)}/content`}>
              Yes, let's select the products
            </NavigationButton>
          </>
        }
      >
        <div className="paragraphs">
          <div>
            <strong>
              A bundle is a special type of product that allows you to offer multiple products together at a discounted
              price.
            </strong>{" "}
            Here's what you can expect by making the switch:
          </div>
          <ol>
            <li>The current content of your product will no longer be editable.</li>
            <li>You'll select the products to include in your new bundle.</li>
            <li>After you save your product, new customers will get access to the selected products.</li>
            <li>
              Your previous customers will retain access to the original content. They will not have access to the new
              content.
            </li>
            <li>All your sales data will remain intact.</li>
          </ol>
          <strong>Conversion is not reversible once completed.</strong>
        </div>
      </Modal>
    </>
  );
};
