export interface ToastProps {
  /** secure uses Cipher shield (e.g. "3 files sealed"). @default "neutral" */
  tone?: "neutral" | "secure" | "caution" | "fault";
  title: string;
  body?: string;
  icon?: string;
  onClose?: () => void;
  style?: React.CSSProperties;
}
export declare function Toast(props: ToastProps): JSX.Element;
