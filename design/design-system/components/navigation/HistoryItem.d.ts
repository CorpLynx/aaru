export interface HistoryItemProps {
  title: string;
  /** Relative time, e.g. "2m", "1d". */
  time?: string;
  active?: boolean;
  /** Shows the Cipher lock glyph. @default true */
  sealed?: boolean;
  /** IDE density (24px rows). */
  dense?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export declare function HistoryItem(props: HistoryItemProps): JSX.Element;
