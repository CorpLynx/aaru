export interface DialogProps {
  /** @default true */
  open?: boolean;
  title: string;
  icon?: string;
  children?: React.ReactNode;
  /** Buttons, right-aligned. */
  actions?: React.ReactNode;
  onClose?: () => void;
  /** px. @default 440 */
  width?: number;
  style?: React.CSSProperties;
}
export declare function Dialog(props: DialogProps): JSX.Element | null;
