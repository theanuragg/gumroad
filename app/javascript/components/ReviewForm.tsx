import * as React from "react";

import { setProductRating } from "$app/data/product_reviews";
import { assertResponseError } from "$app/utils/request";

import { Button } from "$app/components/Button";
import { RatingSelector } from "$app/components/RatingSelector";
import { showAlert } from "$app/components/server-components/Alert";

export type Review = {
  rating: number;
  message: string | null;
};

export const ReviewForm = React.forwardRef<
  HTMLTextAreaElement,
  {
    permalink: string;
    purchaseId: string;
    purchaseEmailDigest?: string;
    review: Review | null;
    onChange?: (review: Review) => void;
    preview?: boolean;
    disabledStatus?: string | null;
    style?: React.CSSProperties;
  }
>(({ permalink, purchaseId, purchaseEmailDigest, review, onChange, preview, disabledStatus, style }, ref) => {
  const [isLoading, setIsLoading] = React.useState(false);
  const [rating, setRating] = React.useState<null | number>(review?.rating ?? null);
  const [message, setMessage] = React.useState(review?.message ?? "");
  const [state, setState] = React.useState<"unsubmitted" | "submitted" | "editing">(
    review ? "submitted" : "unsubmitted",
  );

  const uid = React.useId();

  const handleSubmit = async () => {
    if (!rating) return;

    setIsLoading(true);
    try {
      await setProductRating({
        permalink,
        purchaseId,
        purchaseEmailDigest: purchaseEmailDigest ?? "",
        rating,
        message: message || null,
      });
      setState("submitted");
      onChange?.({ rating, message });
      showAlert("Review submitted successfully!", "success");
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "error");
    }
    setIsLoading(false);
  };

  const disabled = isLoading || preview || !!disabledStatus;

  const form = (
    <>
      <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "space-between", gap: "var(--spacer-2)" }}>
        <label htmlFor={uid}>{state === "unsubmitted" ? "Liked it? Give it a rating:" : "Your rating:"}</label>
        <RatingSelector
          currentRating={rating}
          onChangeCurrentRating={setRating}
          disabled={disabled || state === "submitted"}
        />
      </div>
      {state === "submitted" ? (
        <div style={{ width: "100%" }}>{message ? `"${message}"` : "No written review"}</div>
      ) : (
        <textarea
          id={uid}
          value={message}
          onChange={(evt) => setMessage(evt.target.value)}
          placeholder="Want to leave a written review?"
          disabled={disabled}
          ref={ref}
        />
      )}
      {disabledStatus ? (
        <div role="status" className="warning">
          {disabledStatus}
        </div>
      ) : null}
      {state === "submitted" ? (
        <Button
          onClick={(evt) => {
            evt.preventDefault();
            setState("editing");
          }}
        >
          Edit
        </Button>
      ) : (
        <Button color="primary" disabled={disabled || rating === null} type="submit">
          {state === "editing" ? "Update review" : "Post review"}
        </Button>
      )}
    </>
  );
  return preview ? (
    <div style={style}>{form}</div>
  ) : (
    <form
      onSubmit={(evt) => {
        evt.preventDefault();
        void handleSubmit();
      }}
      style={style}
    >
      {form}
    </form>
  );
});

ReviewForm.displayName = "ReviewForm";
