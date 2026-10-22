export interface SegmentOption { value: string; label: string; icon?: string; }
export interface SegmentedControlProps {
  options: SegmentOption[];
  value: string;
  onChange?: (value: string) => void;
  /** sm 22px (IDE), md 28px. @default "md" */
  size?: "sm" | "md";
  style?: React.CSSProperties;
}
export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;
