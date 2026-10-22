export interface TooltipProps {
  content: React.ReactNode;
  /** @default "top" */
  side?: "top" | "bottom";
  children: React.ReactNode;
  style?: React.CSSProperties;
}
export declare function Tooltip(props: TooltipProps): JSX.Element;
