export interface SelectOption { value: string; label: string; }
export interface SelectProps {
  label?: string;
  value?: string;
  defaultValue?: string;
  options: SelectOption[];
  onChange?: (value: string) => void;
  /** @default "md" */
  size?: "sm" | "md" | "lg";
  style?: React.CSSProperties;
}
export declare function Select(props: SelectProps): JSX.Element;
