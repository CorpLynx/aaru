export interface CitationProps {
  /** e.g. "contracts.docx §4.2" */
  label: string;
  /** 28px touch pill for mobile. */
  pill?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export declare function Citation(props: CitationProps): JSX.Element;
