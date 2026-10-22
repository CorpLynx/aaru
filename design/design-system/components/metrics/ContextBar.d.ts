export interface ContextBarProps {
  /** Thousands of tokens per segment. */
  system?: number;
  documents?: number;
  chat?: number;
  /** Window size in k tokens. @default 128 */
  total?: number;
  /** @default "CONTEXT" */
  label?: string;
  /** @default true */
  legend?: boolean;
  style?: React.CSSProperties;
}
export declare function ContextBar(props: ContextBarProps): JSX.Element;
