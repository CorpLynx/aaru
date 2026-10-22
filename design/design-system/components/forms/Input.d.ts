import * as React from "react";
export interface InputProps {
  label?: string;
  placeholder?: string;
  value?: string;
  defaultValue?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
  icon?: string;
  hint?: string;
  /** Replaces hint and turns border Fault. */
  error?: string;
  /** sm 28 / md 36 / lg 44 (mobile, 16px text). @default "md" */
  size?: "sm" | "md" | "lg";
  disabled?: boolean;
  type?: string;
  /** Mono value text — keys, hashes, endpoints. */
  mono?: boolean;
  style?: React.CSSProperties;
}
export declare function Input(props: InputProps): JSX.Element;
