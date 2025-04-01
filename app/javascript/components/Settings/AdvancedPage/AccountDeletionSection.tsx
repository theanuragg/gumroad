import * as React from "react";
import { cast } from "ts-safe-cast";

import { assertResponseError, request, ResponseError } from "$app/utils/request";

import { Button } from "$app/components/Button";
import { Modal } from "$app/components/Modal";
import { showAlert } from "$app/components/server-components/Alert";

type Props = {
  formatted_balance_to_forfeit: string | null;
};

const AccountDeletionSection = (props: Props) => {
  const [showConfirmationModal, setShowConfirmationModal] = React.useState(false);

  const performAccountDeletion = async () => {
    try {
      const response = await request({
        method: "POST",
        accept: "json",
        url: Routes.deactivate_account_path(),
      });
      const responseData = cast<{ success: true } | { success: false; message: string }>(await response.json());
      if (!responseData.success) throw new ResponseError(responseData.message);
      window.location.href = Routes.root_path();
    } catch (e) {
      assertResponseError(e);
      setShowConfirmationModal(false);
      showAlert(e.message, "error");
    }
  };

  return (
    <section>
      <header>
        <h2>Danger Zone</h2>
      </header>
      <p>
        Deleting your account will permanently delete all of your products and product files, as well as any credit card
        and payout information. You will not be able to restore your account once it's deleted and you will be
        unsubscribed from any memberships. You will also not be able to create a new account with this account's email.
      </p>
      <p>
        <a
          href="#"
          data-helper-prompt="What happens when I delete my Gumroad account and will I be able to reactivate it? Can I delete my Gumroad account if I have a balance? Can I reuse my delted email address to create a new account?"
        >
          Read first before deleting your account.
        </a>
        .
      </p>
      <div>
        <Button color="danger" onClick={() => setShowConfirmationModal(true)}>
          Delete your Gumroad account
        </Button>
      </div>

      <Modal
        open={showConfirmationModal}
        title="Delete account"
        onClose={() => setShowConfirmationModal(false)}
        footer={
          <>
            <Button onClick={() => setShowConfirmationModal(false)}>Cancel</Button>
            <Button color="danger" onClick={() => void performAccountDeletion()}>
              {props.formatted_balance_to_forfeit ? "Yes, forfeit balance and delete" : "Yes, delete my account"}
            </Button>
          </>
        }
      >
        <p>
          {props.formatted_balance_to_forfeit
            ? `You have a balance of ${props.formatted_balance_to_forfeit}. To delete your account, you will need to forfeit your balance. `
            : null}
          <span>
            Deleting your account will permanently delete all of your products and product files, as well as any credit
            card and payout information. You will not be able to restore your account once it's deleted and you will be
            unsubscribed from any memberships. You will also not be able to create a new account with this account's
            email.
          </span>
        </p>
        <p>
          For more information, see <a data-helper-prompt="How do I delete my Gumroad account?">here</a>.
        </p>
      </Modal>
    </section>
  );
};

export default AccountDeletionSection;
