export interface ModelOption { value: string; label: string; icon: string; meta: string; }
export interface ModelToggleProps {
  /** @default "moe" */
  value?: string;
  onChange?: (value: string) => void;
  /** Defaults to Quick (Sparse MoE) / Deep (Heavy Dense). */
  options?: ModelOption[];
  style?: React.CSSProperties;
}
export declare function ModelToggle(props: ModelToggleProps): JSX.Element;
