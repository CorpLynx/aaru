export interface MetricChipProps {
  /** speed = tok/s, engine = iGPU/eGPU, context = window usage. @default "speed" */
  kind?: "speed" | "engine" | "context";
  /** Display string, e.g. "48.2 tok/s", "eGPU · RTX". Context defaults to percent. */
  value?: string;
  /** Speed only: Ember while tokens stream; settles to gray when done. */
  live?: boolean;
  /** Context only: 0–100. Turns Caution at 80. */
  percent?: number;
  style?: React.CSSProperties;
}
export declare function MetricChip(props: MetricChipProps): JSX.Element;
