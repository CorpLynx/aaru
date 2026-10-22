import * as React from "react";
export interface CardProps {
  /** default = ink-900 chrome, raised = ink-850, well = true black (code, metrics). @default "default" */
  tone?: "default" | "raised" | "well";
  /** px. @default 24 */
  padding?: number | string;
  interactive?: boolean;
  selected?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}
export declare function Card(props: CardProps): JSX.Element;
