import * as React from "react";

type Props<OptionId extends string> = {
  value: OptionId;
  onChange: (newOptionId: OptionId) => void;
  options: { id: OptionId; label: string }[];
  className?: string;
  disabled?: boolean;
};
export const TypeSafeOptionSelect = <OptionId extends string>({
  value,
  onChange,
  options,
  className,
  disabled,
  ...rest
}: Props<OptionId> & Omit<React.HTMLAttributes<HTMLSelectElement>, "value" | "onChange"> & { name?: string }) => (
  <select
    value={value}
    /* eslint-disable-next-line @typescript-eslint/consistent-type-assertions */
    onChange={(evt) => onChange(evt.target.value as OptionId)}
    {...rest}
    className={className}
    disabled={disabled}
  >
    {options.map((opt) => (
      <option key={opt.id} value={opt.id}>
        {opt.label}
      </option>
    ))}
  </select>
);
