import { ChangeEvent, useCallback, useState } from "react";

export const useFormField = (initialValue: string) => {
  const [field, setField] = useState(initialValue);

  const onFieldChange = useCallback(
    (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
      setField(e.currentTarget.value);
    },
    [setField]
  );

  return [field, onFieldChange, setField] as const;
};
