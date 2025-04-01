import { NodeViewProps, NodeViewWrapper } from "@tiptap/react";
import * as React from "react";
import { cast } from "ts-safe-cast";

import { TextInput } from "$app/components/Download/CustomField/TextInput";

export const TextInputNodeView = ({ editor, node, updateAttributes }: NodeViewProps) => {
  const label = cast<string | null>(node.attrs.label);
  const type = cast<"shortAnswer" | "longAnswer">(node.type.name);
  const customFieldId = cast<string | null>(node.attrs.id);

  const sharedProps: React.InputHTMLAttributes<HTMLInputElement | HTMLTextAreaElement> = {
    readOnly: true,
    "aria-label": label ?? undefined,
  };

  return (
    <NodeViewWrapper data-drag-handle>
      <fieldset>
        {editor.isEditable ? (
          <>
            <input
              value={label ?? ""}
              placeholder="Title"
              onChange={(evt) => updateAttributes({ label: evt.target.value })}
              style={{
                border: "none",
                background: "none",
                padding: 0,
                margin: 0,
                font: "inherit",
                color: "inherit",
                outline: "none",
                borderRadius: 0,
              }}
            />
            {type === "shortAnswer" ? <input {...sharedProps} /> : <textarea {...sharedProps} />}
          </>
        ) : (
          <TextInput customFieldId={customFieldId ?? ""} type={type} label={label ?? ""} />
        )}
      </fieldset>
    </NodeViewWrapper>
  );
};
